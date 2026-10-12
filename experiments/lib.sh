. /lab/runner/lib/common.sh
. /lab/runner/lib/cluster.sh
. /lab/runner/lib/scenario.sh

exp_dir() {
    RUN_DIR="$RESULTS/$1/$(date -u +%Y%m%dT%H%M%SZ)"
    mkdir -p "$RUN_DIR"
    : > "$RUN_DIR/events.csv"
}

phase_stats() {
    python3 - "$RUN_DIR" "$@" <<'PY'
import json, sys, os
sys.path.insert(0, "/lab/measure")
from analyze import load_k6, percentile
run_dir, label, path = sys.argv[1], sys.argv[2], sys.argv[3]
attempts, acks, giveups = load_k6(path)
ok_first = [a["ms"] for a in attempts if a["ok"] and a["attempt"] == 1]
span = (attempts[-1]["t"] - attempts[0]["t"]) if len(attempts) > 1 else 0
out = {
    "phase": label,
    "acked": len(acks),
    "gave_up": len(giveups),
    "failed_attempts": sum(1 for a in attempts if not a["ok"]),
    "throughput_per_s": round(len(acks) / span, 1) if span else None,
    "p50_ms": percentile(ok_first, 50),
    "p95_ms": percentile(ok_first, 95),
    "p99_ms": percentile(ok_first, 99),
    "max_ms": round(max((a["ms"] for a in attempts), default=0), 1),
    "slow_over_4s": sum(1 for a in attempts if a["ms"] >= 4000),
}
with open(os.path.join(run_dir, "phases.jsonl"), "a", encoding="utf-8") as fh:
    fh.write(json.dumps(out) + "\n")
print(json.dumps(out))
PY
}

run_phase() {
    local label="$1" duration="$2" rate="$3"
    local k6json="$RUN_DIR/k6-$label.json"
    k6 run --quiet --no-usage-report --no-thresholds --out "json=$k6json" \
        -e BASE_URL="$API_URL" -e RUN_ID="exp-$label-$(date +%s)" -e RATE="$rate" -e DURATION="$duration" \
        /lab/measure/transfers.js > "$RUN_DIR/k6-$label.log" 2>&1 &
    K6_PID=$!
}

finish_phase() {
    local label="$1"
    wait "$K6_PID" || true
    phase_stats "$label" "$RUN_DIR/k6-$label.json"
    gzip -f "$RUN_DIR/k6-$label.json"
}

phases_table() {
    python3 - "$RUN_DIR/phases.jsonl" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8")]
print("| phase | acked | throughput/s | p50 ms | p95 ms | p99 ms | max ms | attempts >= 4 s | failed attempts | gave up |")
print("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
for r in rows:
    print(f"| {r['phase']} | {r['acked']} | {r['throughput_per_s']} | {r['p50_ms']} | {r['p95_ms']} | {r['p99_ms']} | {r['max_ms']} | {r['slow_over_4s']} | {r['failed_attempts']} | {r['gave_up']} |")
PY
}

set_system() {
    local primary="$1" setting="$2" value="$3"
    nexec "$primary" lab-node psql -d postgres -c "ALTER SYSTEM SET $setting = '$value'" -c "SELECT pg_reload_conf()" >/dev/null
    sleep 1
}

reset_system() {
    local primary="$1" setting="$2"
    nexec "$primary" lab-node psql -d postgres -c "ALTER SYSTEM RESET $setting" -c "SELECT pg_reload_conf()" >/dev/null
    sleep 1
}
