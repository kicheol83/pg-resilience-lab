RUN_DIR=""
RUN_START=""
K6_PID=""

ev() {
    printf '%s,%s\n' "$(ts)" "$*" >> "$RUN_DIR/events.csv"
    say "event: $*"
}

start_workload() {
    local run_id="$1" duration="$2" rate="$3"
    k6 run --quiet --no-usage-report --no-thresholds \
        --out "json=$RUN_DIR/k6.json" \
        -e BASE_URL="$API_URL" -e RUN_ID="$run_id" -e RATE="$rate" -e DURATION="$duration" \
        /lab/measure/transfers.js > "$RUN_DIR/k6.log" 2>&1 &
    K6_PID=$!
    if ! wait_until 180 grep -q '"lab_attempt"' "$RUN_DIR/k6.json"; then
        cat "$RUN_DIR/k6.log" >&2
        die "workload did not start"
    fi
}

stop_workload() {
    [ -n "$K6_PID" ] || return 0
    wait "$K6_PID" || true
    K6_PID=""
}

scenario_defaults() {
    SCENARIO=""
    TITLE=""
    WARMUP=20
    RATE="${LAB_RATE:-20}"
    DURATION="${LAB_DURATION:-150s}"
    RECOVERY_TIMEOUT=180
    inject() { die "scenario has no inject()"; }
    respond() { :; }
    heal() { :; }
    before_run() { :; }
    after_run() { :; }
}

write_meta() {
    local run_id="$1" run_no="$2"
    jq -n --arg scenario "$SCENARIO" --arg title "$TITLE" --arg run_id "$run_id" \
        --arg started_at "$(now_iso)" --argjson rate "$RATE" --arg duration "$DURATION" --argjson run "$run_no" \
        '{scenario:$scenario,title:$title,run_id:$run_id,started_at:$started_at,rate:$rate,duration:$duration,run:$run,extra:{}}' \
        > "$RUN_DIR/meta.json"
}

meta_extra() {
    local key="$1" value="$2" tmp
    tmp="$(mktemp)"
    jq --arg k "$key" --arg v "$value" '.extra[$k] = $v' "$RUN_DIR/meta.json" > "$tmp" && mv "$tmp" "$RUN_DIR/meta.json"
}

run_once() {
    local run_no="$1" run_id
    before_run
    ensure_baseline
    run_id="${SCENARIO}-$(date -u +%Y%m%dT%H%M%SZ)-r${run_no}"
    RUN_DIR="$RESULTS/$SCENARIO/$(date -u +%Y%m%dT%H%M%SZ)-r${run_no}"
    mkdir -p "$RUN_DIR"
    RUN_START="$(ts)"
    write_meta "$run_id" "$run_no"
    repmgr_show > "$RUN_DIR/cluster-before.txt" 2>&1 || true
    ev "workload_start"
    start_workload "$run_id" "$DURATION" "$RATE"
    sleep "$WARMUP"
    ev "inject"
    ( inject ) || ev "inject_step_failed"
    ( respond ) || ev "respond_step_failed"
    if wait_until "$RECOVERY_TIMEOUT" api_write_ok; then
        ev "write_probe_ok"
    else
        ev "write_probe_timeout"
    fi
    ev "primary_now_$(current_primary || echo none)"
    stop_workload
    ev "workload_done"
    repmgr_show > "$RUN_DIR/cluster-after.txt" 2>&1 || true
    ( heal ) || ev "heal_step_failed"
    local baseline_ok=1
    if ( ensure_baseline ); then
        ev "healed"
    else
        baseline_ok=0
        ev "baseline_failed"
    fi
    collect_node_events "$RUN_START" "$RUN_DIR/node-events.csv"
    awk -F, 'BEGIN{OFS=","} {t=$1; n=$2; $1=""; $2=""; sub(/^,,/, ""); print t, "node:" n ":" $0}' "$RUN_DIR/node-events.csv" >> "$RUN_DIR/events.csv"
    sort -t, -k1,1n -o "$RUN_DIR/events.csv" "$RUN_DIR/events.csv"
    gzip -f "$RUN_DIR/k6.json"
    python3 /lab/measure/analyze.py "$RUN_DIR" | tee "$RUN_DIR/analyze.log"
    after_run
    [ "$baseline_ok" = 1 ] || die "run $run_no was analyzed, but the baseline could not be restored; see the warnings above"
}

run_scenario() {
    local file="$1" runs="${2:-1}" i
    scenario_defaults
    . "$file"
    say "scenario $SCENARIO: $TITLE ($runs run(s))"
    for i in $(seq 1 "$runs"); do
        run_once "$i"
    done
    python3 /lab/measure/report.py "$RESULTS" > /dev/null
    say "summary updated: results/SUMMARY.md"
}
