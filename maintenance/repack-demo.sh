#!/usr/bin/env bash
set -euo pipefail
. /lab/experiments/lib.sh

ROWS="${BLOAT_ROWS:-600000}"
RATE="${LAB_RATE:-20}"

ensure_baseline
primary="$(current_primary)"
exp_dir maintenance-repack
psql_su() { nexec "$primary" lab-node psql -d ledgercore -Atq "$@"; }

make_bloat() {
    psql_su -c "
insert into idempotency_keys (key, endpoint, request_hash, response_status, response_body, expires_at)
select 'bloat-' || g || '-' || extract(epoch from clock_timestamp())::bigint,
       'POST /v1/transfers', md5(g::text), 201,
       jsonb_build_object('id', gen_random_uuid(), 'note', repeat('x', 400)),
       now() + interval '1 day'
from generate_series(1, $ROWS) g" >/dev/null
    psql_su -c "update idempotency_keys set expires_at = created_at + interval '1 millisecond' where key like 'bloat-%' and (hashtext(key) & 1) <> 0" >/dev/null
    local deleted=1
    while [ "$deleted" != "0" ]; do
        deleted="$(psql_su -c "select purge_expired_idempotency_keys(50000)")"
    done
    psql_su -c "vacuum (analyze) idempotency_keys" >/dev/null
}

size_of() {
    psql_su -c "select pg_total_relation_size('idempotency_keys')"
}

free_pct() {
    psql_su -c "select round(approx_free_percent::numeric, 1) from pgstattuple_approx('idempotency_keys')"
}

measure() {
    local label="$1" cmd="$2" before after t0 t1
    make_bloat
    before="$(size_of)"
    local free_before
    free_before="$(free_pct)"
    run_phase "$label" 90s "$RATE"
    sleep 20
    t0="$(ts)"
    ev "$label:start"
    eval "$cmd"
    t1="$(ts)"
    ev "$label:end"
    finish_phase "$label"
    after="$(size_of)"
    printf '| %s | %s | %s %% | %s | %.1f |\n' "$label" \
        "$(numfmt --to=iec "$before")" "$free_before" "$(numfmt --to=iec "$after")" \
        "$(awk "BEGIN{print $t1 - $t0}")" >> "$RUN_DIR/sizes.md"
}

: > "$RUN_DIR/sizes.md"
measure vacuum-full "psql_su -c 'vacuum full idempotency_keys' >/dev/null"
measure pg-repack "nexec \"$primary\" bash -c '. /usr/local/bin/lab-common.sh; as_pg \"\$(pg_bin)/pg_repack\" -h /run/postgresql -U postgres -d ledgercore -t idempotency_keys --no-kill-backend --wait-timeout=60' >/dev/null 2>&1"

{
    echo "# VACUUM FULL vs pg_repack under write load"
    echo
    echo "idempotency_keys is filled with $ROWS rows and about half of them are purged by purge_expired_idempotency_keys(),"
    echo "which leaves the table mostly empty space that plain VACUUM cannot give back. Each method then rebuilds the"
    echo "table while $RATE transfers/s keep writing to the same table through the API."
    echo
    echo "| method | size before | free space before | size after | duration s |"
    echo "| --- | --- | --- | --- | --- |"
    cat "$RUN_DIR/sizes.md"
    echo
    echo "Transfer latency during each phase (the phase includes 20 s before the rebuild starts):"
    echo
    phases_table
} > "$RUN_DIR/result.md"
cat "$RUN_DIR/result.md"
python3 /lab/measure/report.py "$RESULTS" >/dev/null
