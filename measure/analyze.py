import csv
import gzip
import json
import os
import re
import statistics
import subprocess
import sys
from datetime import datetime

FRACTION = re.compile(r"\.(\d+)")


def parse_time(value):
    value = FRACTION.sub(lambda m: "." + m.group(1)[:6].ljust(6, "0"), value, count=1)
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    return datetime.fromisoformat(value).timestamp()


def open_any(path):
    if path.endswith(".gz"):
        return gzip.open(path, "rt", encoding="utf-8")
    return open(path, encoding="utf-8")


def load_k6(path):
    attempts, acks, giveups = [], [], []
    with open_any(path) as handle:
        for line in handle:
            if '"lab_' not in line:
                continue
            point = json.loads(line)
            if point.get("type") != "Point":
                continue
            data = point["data"]
            tags = data.get("tags", {})
            t = parse_time(data["time"])
            metric = point["metric"]
            if metric == "lab_attempt":
                attempts.append({
                    "t": t,
                    "ok": tags.get("ok") == "1",
                    "status": tags.get("status", ""),
                    "attempt": int(tags.get("attempt", "1")),
                    "key": tags.get("key", ""),
                    "ms": data.get("value", 0.0),
                })
            elif metric == "lab_ack":
                acks.append({
                    "t": t,
                    "tx": tags.get("tx", ""),
                    "key": tags.get("key", ""),
                    "replay": tags.get("replay") == "1",
                    "attempts": int(tags.get("attempts", "1")),
                })
            elif metric == "lab_giveup":
                giveups.append({"t": t, "key": tags.get("key", ""), "status": tags.get("status", "")})
    attempts.sort(key=lambda a: a["t"])
    acks.sort(key=lambda a: a["t"])
    return attempts, acks, giveups


def load_events(path):
    events = []
    if not os.path.exists(path):
        return events
    with open(path, encoding="utf-8") as handle:
        for row in csv.reader(handle):
            if len(row) >= 2:
                try:
                    events.append((float(row[0]), ",".join(row[1:])))
                except ValueError:
                    continue
    return events


def first_event(events, name):
    for t, label in events:
        if label == name:
            return t
    return None


def outage(attempts, inject_t):
    if inject_t is None:
        return None
    after = [a for a in attempts if a["t"] >= inject_t]
    first_fail = next((a for a in after if not a["ok"]), None)
    if first_fail is None:
        return {"had_errors": False, "client_gap_s": 0.0, "rto_from_inject_s": 0.0, "failed_attempts": 0}
    before_ok = [a for a in attempts if a["ok"] and a["t"] < first_fail["t"]]
    last_ok_before = before_ok[-1]["t"] if before_ok else inject_t
    recovered = None
    for a in after:
        if a["t"] > first_fail["t"] and a["ok"]:
            later = [b for b in after if b["t"] > a["t"] and b["t"] <= a["t"] + 3.0]
            if later and sum(1 for b in later if b["ok"]) / len(later) >= 0.9:
                recovered = a["t"]
                break
    failed = sum(1 for a in after if not a["ok"])
    if recovered is None:
        return {"had_errors": True, "client_gap_s": None, "rto_from_inject_s": None, "failed_attempts": failed}
    return {
        "had_errors": True,
        "client_gap_s": round(recovered - last_ok_before, 2),
        "rto_from_inject_s": round(recovered - inject_t, 2),
        "failed_attempts": failed,
        "first_error_status": first_fail["status"],
    }


def max_success_gap(attempts, start, end):
    oks = [a["t"] for a in attempts if a["ok"] and start <= a["t"] <= end]
    if len(oks) < 2:
        return None
    return round(max(b - a for a, b in zip(oks, oks[1:])), 2)


def psql(sql, conninfo, password, copy_file=None):
    env = dict(os.environ, PGPASSWORD=password)
    script = sql
    proc = subprocess.run(
        ["psql", conninfo, "-X", "-Atq", "-v", "ON_ERROR_STOP=1"],
        input=script, text=True, capture_output=True, env=env, timeout=600,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip())
    return [line for line in proc.stdout.splitlines() if line.strip()]


def db_checks(run_dir, run_id, acks):
    conninfo = os.environ.get(
        "CHECK_CONNINFO",
        "host=haproxy port=5000 dbname=ledgercore user=ledger_ro sslmode=verify-full sslrootcert=/certs/ca.crt connect_timeout=5",
    )
    password = os.environ.get("CHECK_PASSWORD", os.environ.get("LEDGER_RO_PASSWORD", ""))
    ids = sorted({a["tx"] for a in acks if a["tx"]})
    with open(os.path.join(run_dir, "acked_tx.txt"), "w", encoding="utf-8") as handle:
        handle.write("\n".join(ids) + ("\n" if ids else ""))
    array = "{" + ",".join(ids) + "}"
    sql = f"""
SELECT 'missing', count(*) FROM unnest('{array}'::uuid[]) AS a(id) WHERE NOT EXISTS (SELECT 1 FROM transactions t WHERE t.id = a.id);
SELECT 'duplicates', count(*) FROM (
    SELECT metadata->>'labKey' FROM transactions
    WHERE type = 'TRANSFER' AND metadata->>'labRun' = '{run_id}'
    GROUP BY 1 HAVING count(*) > 1) d;
SELECT 'committed_for_run', count(*) FROM transactions WHERE type = 'TRANSFER' AND metadata->>'labRun' = '{run_id}';
SELECT 'integrity_violations', count(*) FROM verify_ledger_integrity();
SELECT 'unbalanced_currencies', count(*) FROM (
    SELECT a.currency,
           sum(CASE WHEN e.direction = 'DEBIT' THEN e.amount ELSE 0 END) AS d,
           sum(CASE WHEN e.direction = 'CREDIT' THEN e.amount ELSE 0 END) AS c
    FROM ledger_entries e JOIN accounts a ON a.id = e.account_id
    GROUP BY a.currency) x WHERE d <> c;
"""
    rows = psql(sql, conninfo, password)
    result = {}
    for row in rows:
        k, v = row.split("|", 1)
        result[k] = int(v)
    return result


def percentile(values, p):
    if not values:
        return None
    values = sorted(values)
    k = (len(values) - 1) * p / 100.0
    f = int(k)
    c = min(f + 1, len(values) - 1)
    return round(values[f] + (values[c] - values[f]) * (k - f), 1)


def main():
    run_dir = sys.argv[1]
    meta = json.load(open(os.path.join(run_dir, "meta.json"), encoding="utf-8"))
    run_id = meta["run_id"]
    k6_path = os.path.join(run_dir, "k6.json.gz")
    if not os.path.exists(k6_path):
        k6_path = os.path.join(run_dir, "k6.json")
    attempts, acks, giveups = load_k6(k6_path)
    events = load_events(os.path.join(run_dir, "events.csv"))
    inject_t = first_event(events, "inject")
    out = outage(attempts, inject_t)
    start = attempts[0]["t"] if attempts else 0
    end = attempts[-1]["t"] if attempts else 0
    first_try_ms = [a["ms"] for a in attempts if a["ok"] and a["attempt"] == 1]
    checks = {}
    check_error = None
    if os.environ.get("SKIP_DB_CHECKS") != "1":
        try:
            checks = db_checks(run_dir, run_id, acks)
        except Exception as exc:
            check_error = str(exc)
    with gzip.open(os.path.join(run_dir, "attempts.csv.gz"), "wt", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["t", "ok", "status", "attempt", "ms", "key"])
        for a in attempts:
            writer.writerow([f"{a['t']:.3f}", int(a["ok"]), a["status"], a["attempt"], f"{a['ms']:.1f}", a["key"]])
    summary = {
        "scenario": meta.get("scenario"),
        "title": meta.get("title"),
        "run_id": run_id,
        "started_at": meta.get("started_at"),
        "rate_per_s": meta.get("rate"),
        "logical_transfers": len(acks) + len(giveups),
        "acked": len(acks),
        "gave_up": len(giveups),
        "acked_after_retry": sum(1 for a in acks if a["attempts"] > 1),
        "idempotent_replays": sum(1 for a in acks if a["replay"]),
        "attempts": len(attempts),
        "failed_attempts_total": sum(1 for a in attempts if not a["ok"]),
        "max_success_gap_s": max_success_gap(attempts, start, end),
        "latency_ms_p50": percentile(first_try_ms, 50),
        "latency_ms_p95": percentile(first_try_ms, 95),
        "latency_ms_p99": percentile(first_try_ms, 99),
        "outage": out,
        "rpo_missing_acked": checks.get("missing"),
        "duplicate_transfers": checks.get("duplicates"),
        "committed_for_run": checks.get("committed_for_run"),
        "integrity_violations": checks.get("integrity_violations"),
        "unbalanced_currencies": checks.get("unbalanced_currencies"),
        "db_check_error": check_error,
        "events": [{"t": round(t - (inject_t or start), 2), "event": e} for t, e in events],
        "extra": meta.get("extra", {}),
    }
    passed = (
        check_error is None
        and summary["rpo_missing_acked"] == 0
        and summary["duplicate_transfers"] == 0
        and summary["integrity_violations"] == 0
        and summary["unbalanced_currencies"] == 0
    )
    summary["data_safe"] = passed
    json.dump(summary, open(os.path.join(run_dir, "summary.json"), "w", encoding="utf-8"), indent=2, ensure_ascii=False)
    write_markdown(run_dir, summary)
    print(json.dumps({k: summary[k] for k in ("scenario", "acked", "rpo_missing_acked", "duplicate_transfers", "integrity_violations", "data_safe")} | {"outage": out}, ensure_ascii=False))


def fmt(v, unit=""):
    if v is None:
        return "-"
    return f"{v}{unit}"


def write_markdown(run_dir, s):
    o = s["outage"] or {}
    lines = [
        f"# {s['scenario']} - {s['title']}",
        "",
        f"- run: `{s['run_id']}` ({s['started_at']})",
        f"- workload: {s['rate_per_s']} transfers/s, logical transfers {s['logical_transfers']}, acked {s['acked']}, gave up {s['gave_up']}",
        "",
        "| metric | value |",
        "| --- | --- |",
        f"| RTO from injection | {fmt(o.get('rto_from_inject_s'), ' s')} |",
        f"| client-observed write gap | {fmt(o.get('client_gap_s'), ' s')} |",
        f"| failed attempts | {fmt(o.get('failed_attempts'))} |",
        f"| acked after retry | {s['acked_after_retry']} |",
        f"| idempotent replays | {s['idempotent_replays']} |",
        f"| RPO: acked transfers missing | {fmt(s['rpo_missing_acked'])} |",
        f"| duplicate transfers | {fmt(s['duplicate_transfers'])} |",
        f"| ledger integrity violations | {fmt(s['integrity_violations'])} |",
        f"| unbalanced currencies | {fmt(s['unbalanced_currencies'])} |",
        f"| first-try latency p50 / p95 / p99 | {fmt(s['latency_ms_p50'])} / {fmt(s['latency_ms_p95'])} / {fmt(s['latency_ms_p99'])} ms |",
        f"| data safe | {'yes' if s['data_safe'] else 'NO'} |",
        "",
        "## Timeline (seconds from injection)",
        "",
        "| t | event |",
        "| --- | --- |",
    ]
    for e in s["events"]:
        lines.append(f"| {e['t']:+.2f} | {e['event']} |")
    if s.get("db_check_error"):
        lines += ["", f"DB check error: `{s['db_check_error']}`"]
    open(os.path.join(run_dir, "summary.md"), "w", encoding="utf-8").write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
