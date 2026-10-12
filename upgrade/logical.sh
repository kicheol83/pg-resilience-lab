#!/usr/bin/env bash
set -euo pipefail
. /lab/runner/lib/common.sh
. /lab/runner/lib/cluster.sh
. /lab/runner/lib/scenario.sh

SRC=pg1
DST=pg18
PUB=lab_upgrade

container_running "$DST" || die "start the target first: lab.ps1 upgrade-node (docker compose --profile upgrade up -d pg18)"

src_sql() { nexec "$SRC" lab-node psql -d ledgercore -Atq "$@"; }
dst_sql() { nexec "$DST" lab-node psql -d ledgercore -Atq "$@"; }

caught_up() {
    local lsn lag
    lsn="$(src_sql -c "select pg_current_wal_lsn()")"
    lag="$(src_sql -c "select coalesce(pg_wal_lsn_diff('$lsn', confirmed_flush_lsn), -1) from pg_replication_slots where slot_name = '$PUB'")"
    [ -n "$lag" ] && [ "$lag" -le 0 ] 2>/dev/null
}

initial_sync_done() {
    [ "$(dst_sql -c "select count(*) from pg_subscription_rel where srsubstate <> 'r'")" = "0" ] \
        && [ "$(dst_sql -c "select count(*) from pg_subscription_rel")" != "0" ]
}

TABLES=""

table_counts() {
    local node="$1" q="" t
    if [ -z "$TABLES" ]; then
        TABLES="$(src_sql -c "select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relispartition order by 1" | tr '\n' ' ')"
    fi
    for t in $TABLES; do
        q+="${q:+ union all }select '$t=' || count(*) from public.\"$t\""
    done
    nexec "$node" lab-node psql -d ledgercore -Atq -c "$q" | sort | tr '\n' ' '
}

ensure_baseline
RUN_DIR="$RESULTS/upgrade-logical/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$RUN_DIR"
: > "$RUN_DIR/events.csv"
SCENARIO=upgrade-logical
TITLE="Major upgrade 17 -> 18 with logical replication and a HAProxy cutover"
RATE="${LAB_RATE:-20}"
DURATION="${LAB_DURATION:-240s}"
run_id="upgrade-logical-$(date +%s)"
write_meta "$run_id" 1
RUN_START="$(ts)"
meta_extra source_version "$(src_sql -c 'show server_version')"
meta_extra target_version "$(dst_sql -c 'show server_version')"

if [ "$(dst_sql -c "select count(*) from pg_tables where schemaname = 'public'")" != "0" ]; then
    die "$DST already has tables; reset it with: docker compose --profile upgrade rm -sfv pg18 && docker volume rm pglab_pg18_data"
fi

ev "schema_copy_start"
nexec "$SRC" bash -c '. /usr/local/bin/lab-common.sh; as_pg "$(pg_bin)/pg_dump" -h /run/postgresql -U postgres -d ledgercore --schema-only --no-publications --no-subscriptions' \
    | docker exec -i "$(cname "$DST")" lab-node psql -d ledgercore -v ON_ERROR_STOP=0 > "$RUN_DIR/schema-restore.log" 2>&1 || true
ev "schema_copied"

src_sql -c "DROP PUBLICATION IF EXISTS $PUB" -c "CREATE PUBLICATION $PUB FOR ALL TABLES WITH (publish_via_partition_root = true)" >/dev/null
nexec "$DST" bash -c "printf '%s\n' \"CREATE SUBSCRIPTION $PUB CONNECTION 'host=$SRC-db port=5432 dbname=ledgercore user=repmgr sslmode=verify-full sslrootcert=/etc/pg-tls/ca.crt password=\$REPMGR_PASSWORD' PUBLICATION $PUB WITH (copy_data = true, slot_name = '$PUB');\" | lab-node psql -d ledgercore" >/dev/null
ev "subscription_created"

table_counts "$SRC" >/dev/null
ev "workload_start"
start_workload "$run_id" "$DURATION" "$RATE"
wait_until 600 initial_sync_done || die "initial table sync did not finish"
ev "initial_sync_done"
wait_until 120 caught_up || warn "subscriber is still behind before cutover"
sleep 10

ev "inject"
ev "cutover_start"
nexec "$SRC" lab-node fence
ev "source_read_only"
wait_until 60 caught_up || die "subscriber did not catch up after writes stopped"
ev "subscriber_caught_up"
src_counts="$(table_counts "$SRC")"
dst_counts="$(table_counts "$DST")"
meta_extra counts_source_at_cutover "$src_counts"
meta_extra counts_target_at_cutover "$dst_counts"
if [ "$src_counts" = "$dst_counts" ]; then ev "row_counts_match"; else ev "row_counts_differ"; fi
dst_sql -c "
do \$\$
declare r record;
begin
  for r in
    select s.oid::regclass as seq, d.refobjid::regclass as tbl, a.attname as col
    from pg_class s
    join pg_depend d on d.objid = s.oid and d.classid = 'pg_class'::regclass and d.refclassid = 'pg_class'::regclass
    join pg_attribute a on a.attrelid = d.refobjid and a.attnum = d.refobjsubid
    where s.relkind = 'S'
  loop
    execute format('select setval(%L, coalesce((select max(%I) from %s), 0) + 1000, false)', r.seq, r.col, r.tbl);
  end loop;
end \$\$" >/dev/null
ev "sequences_synced"
dst_sql -c "ALTER SUBSCRIPTION $PUB DISABLE" -c "ALTER SUBSCRIPTION $PUB SET (slot_name = NONE)" -c "DROP SUBSCRIPTION $PUB" >/dev/null
src_sql -c "SELECT pg_drop_replication_slot('$PUB')" -c "DROP PUBLICATION $PUB" >/dev/null || true
ev "subscription_dropped"
haproxy_cmd "set server pg_primary/$DST state ready" >/dev/null
for n in $DATA_NODES; do haproxy_cmd "set server pg_primary/$n state maint" >/dev/null; done
ev "haproxy_points_to_$DST"
wait_until 60 api_write_ok || warn "writes are not flowing to $DST yet"
ev "cutover_done"
stop_workload
ev "workload_done"

gzip -f "$RUN_DIR/k6.json"
CHECK_CONNINFO="host=haproxy port=5000 dbname=ledgercore user=ledger_ro sslmode=verify-full sslrootcert=/certs/ca.crt connect_timeout=5" \
    python3 /lab/measure/analyze.py "$RUN_DIR" | tee "$RUN_DIR/analyze.log"
python3 /lab/measure/report.py "$RESULTS" >/dev/null
say "application now writes to $DST; pg1 is fenced read-only. Run 'lab.ps1 reset' to return to the 17 cluster."
