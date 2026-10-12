#!/usr/bin/env bash
set -euo pipefail
. /lab/experiments/lib.sh

WRITERS="${WRITERS:-4}"
PARTITION_S="${PARTITION_S:-20}"

writer() {
    local phase="$1" w="$2" target="$3" timeout_ms="$4" until="$5" out="$6" n=0 i sql
    while [ "$(date +%s)" -lt "$until" ]; do
        sql=""
        for i in $(seq 1 40); do
            n=$((n + 1))
            sql+="insert into users (email) values ('leak-$phase-$w-$n@lab.test') returning email;"$'\n'
            sql+="select pg_sleep(0.05);"$'\n'
        done
        printf '%s' "$sql" | PGPASSWORD="$LEDGER_APP_PASSWORD" PGOPTIONS="-c statement_timeout=$timeout_ms" \
            psql "host=$target dbname=ledgercore user=ledger_app sslmode=require connect_timeout=3" -X -Atq 2>>"$out.err" \
            | grep '^leak-' >> "$out" || true
        sleep 0.2
    done
}

interrupter() {
    local action="$1" until="$2"
    [ "$action" = "none" ] && return 0
    while [ "$(date +%s)" -lt "$until" ]; do
        sql_node pg1 -c "select count($action(pid)) from pg_stat_activity where wait_event = 'SyncRep' and usename = 'ledger_app'" >/dev/null 2>&1 || true
        sleep 1
    done
}

phase() {
    local name="$1" target="$2" timeout_ms="$3" action="$4" acked_file pids=() w until missing total warned
    say "phase $name: writers -> $target, statement_timeout=${timeout_ms} ms, interrupt SyncRep waits with: $action"
    ensure_baseline
    acked_file="$RUN_DIR/$name.acked"
    : > "$acked_file"
    until=$(( $(date +%s) + PARTITION_S + 30 ))
    for w in $(seq 1 "$WRITERS"); do
        writer "$name" "$w" "$target" "$timeout_ms" "$until" "$acked_file" &
        pids+=("$!")
    done
    sleep 8
    ev "$name:partition_pg1_from_replicas"
    net_disconnect pg1 db
    interrupter "$action" "$(( $(date +%s) + PARTITION_S ))" &
    local ipid=$!
    sleep "$PARTITION_S"
    wait "$ipid" || true
    net_connect pg1 db
    ev "$name:partition_healed"
    for w in "${pids[@]}"; do wait "$w" || true; done
    ensure_baseline
    total="$(sort -u "$acked_file" | wc -l)"
    missing="$(sort -u "$acked_file" | awk 'BEGIN{printf "select count(*) from unnest(array["} {printf "%s'\''%s'\''", (NR>1?",":""), $0} END{print "]::text[]) e where not exists (select 1 from users u where u.email = e)"}' \
        | PGPASSWORD="$LEDGER_RO_PASSWORD" psql "$(conn ledger_ro)" -X -Atq)"
    warned="$(grep -c 'canceling wait for synchronous replication due to user request' "$acked_file.err" 2>/dev/null || true)"
    echo "| $name | $target | $timeout_ms | $action | $total | ${warned:-0} | $missing |" >> "$RUN_DIR/table.md"
    say "phase $name: acked $total, cancelled sync waits reported as success $warned, acked but lost $missing"
}

exp_dir ack-leak
: > "$RUN_DIR/table.md"
phase timeout-only "pg1 port=5432" 2000 none
phase cancel-direct "pg1 port=5432" 30000 pg_cancel_backend
phase cancel-haproxy "haproxy port=5000" 30000 pg_cancel_backend
phase terminate-haproxy "haproxy port=5000" 30000 pg_terminate_backend
{
    echo "# Acknowledged-but-lost commits under a partition"
    echo
    echo "$WRITERS writers insert rows in autocommit mode while pg1 is cut off from both replicas and the witness for ${PARTITION_S} s."
    echo "Their commits wait for a synchronous standby that cannot answer. Each phase interrupts those waits differently,"
    echo "then the partition heals, pg1 is rewound to follow the new primary, and every row a writer saw as committed is"
    echo "looked up on the surviving cluster."
    echo
    echo "| phase | target | statement_timeout ms | action on SyncRep waits (every 1 s) | acked rows | sync waits cancelled and reported as success | acked but lost |"
    echo "| --- | --- | --- | --- | --- | --- | --- |"
    cat "$RUN_DIR/table.md"
} > "$RUN_DIR/result.md"
cat "$RUN_DIR/result.md"
python3 /lab/measure/report.py "$RESULTS" >/dev/null
