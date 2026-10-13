SCENARIO=09-accidental-drop-pitr
TITLE="Operator drops ledger_entries; recovered with PITR to the transaction before the DROP"
DURATION="${LAB_DURATION_PITR:-300s}"
RECOVERY_TIMEOUT=600

inject() {
    LSN_BEFORE="$(sql_node pg1 -c "select pg_current_wal_lsn()")"
    echo "$LSN_BEFORE" > "$RUN_DIR/lsn_before"
    sql_node pg1 -c "select timeline_id from pg_control_checkpoint()" > "$RUN_DIR/timeline_before"
    meta_extra lsn_before "$LSN_BEFORE"
    local i
    for i in $(seq 1 20); do
        if sql_as ledger_owner -c "set lock_timeout = '2s'" -c "DROP TABLE ledger_entries CASCADE" >/dev/null 2>&1; then
            ev "accident_drop_table_ledger_entries"
            return 0
        fi
        sleep 0.5
    done
    die "could not drop ledger_entries"
}

find_drop_xid() {
    LSN_BEFORE="$(cat "$RUN_DIR/lsn_before")"
    local tl
    tl="$(cat "$RUN_DIR/timeline_before")"
    nexec pg1 bash -c ". /usr/local/bin/lab-common.sh; as_pg \"\$(pg_bin)/pg_waldump\" -p \"\$PGDATA/pg_wal\" -t $tl -s $LSN_BEFORE 2>/dev/null" \
        | grep -m 1 -E 'desc: COMMIT .*rels:' | sed -E 's/.*tx: *([0-9]+),.*/\1/'
}

pg1_promoted() {
    [ "$(docker exec "$(cname pg1)" lab-node psql -d postgres -Atc 'select pg_is_in_recovery()' 2>/dev/null)" = "f" ]
}

pg1_postgres_running() {
    nexec pg1 bash -c '. /usr/local/bin/lab-common.sh; as_pg "$(pg_bin)/pg_ctl" -D "$PGDATA" status' >/dev/null 2>&1
}

wait_for_promotion() {
    local deadline=$(( $(date +%s) + 600 ))
    until pg1_promoted; do
        if ! pg1_postgres_running; then
            ev "pitr_recovery_failed"
            nexec pg1 tail -n 12 /var/log/postgresql/postgresql.log >&2 || true
            die "PostgreSQL on pg1 stopped during PITR recovery; see the log lines above"
        fi
        [ "$(date +%s)" -lt "$deadline" ] || die "pg1 was not promoted within 600s"
        sleep 2
    done
}

respond() {
    sleep 2
    ev "standby_pg2_table_missing=$(sql_node pg2 -c "select to_regclass('ledger_entries') is null")"
    ev "standby_pg3_table_missing=$(sql_node pg3 -c "select to_regclass('ledger_entries') is null")"
    sleep 8
    ev "incident_detected"
    DROP_XID="$(find_drop_xid)"
    [ -n "$DROP_XID" ] || die "could not locate the DROP commit in WAL"
    meta_extra drop_xid "$DROP_XID"
    ev "drop_commit_xid_${DROP_XID}"

    local n
    for n in pg1 pg2 pg3 witness; do nexec "$n" lab-node pause-repmgrd; done
    for n in pg2 pg3 pg1; do nexec "$n" lab-node stop fast; done
    ev "cluster_stopped_for_restore"

    local t0
    t0="$(ts)"
    nexec pg1 gosu postgres pgbackrest --stanza=ledger --delta --type=xid --target="$DROP_XID" \
        --target-exclusive --target-action=promote restore \
        || { ev "pgbackrest_restore_failed"; die "pgbackrest restore failed on pg1"; }
    ev "pgbackrest_restore_done"
    nexec pg1 lab-node start
    wait_for_promotion
    meta_extra restore_and_recovery_s "$(awk "BEGIN{printf \"%.1f\", $(ts) - $t0}")"
    ev "pg1_recovered_and_promoted"
    nexec pg1 lab-node psql -d postgres \
        -c "ALTER SYSTEM RESET recovery_target_xid" \
        -c "ALTER SYSTEM RESET recovery_target_inclusive" \
        -c "ALTER SYSTEM RESET recovery_target_action" \
        -c "SELECT pg_reload_conf()" >/dev/null
    ev "recovery_target_settings_removed"
    nexec pg1 lab-node repmgr primary register -F >/dev/null 2>&1
    nexec pg1 lab-node resume-repmgrd
    ev "entries_after_restore=$(sql_node pg1 -c 'select count(*) from ledger_entries')"
    nexec backup gosu postgres pgbackrest --stanza=ledger --type=full backup >/dev/null
    ev "post_restore_full_backup_done"

    for n in pg2 pg3; do
        if nexec "$n" gosu postgres pgbackrest --stanza=ledger --delta --type=standby --target-timeline=latest restore >/dev/null 2>&1 \
            && nexec "$n" bash -c ". /usr/local/bin/lab-ops.sh; render_repmgr_conf; repmgr_cmd -d \"\$(conninfo_for pg1)\" standby clone --recovery-conf-only -F" >/dev/null 2>&1 \
            && nexec "$n" lab-node start \
            && nexec "$n" lab-node repmgr standby register -F >/dev/null 2>&1; then
            ev "${n}_reseeded_by_pgbackrest_delta"
        else
            nexec "$n" lab-node rebuild pg1 >/dev/null
            ev "${n}_reseeded_by_clone"
        fi
        nexec "$n" lab-node resume-repmgrd
    done
    nexec witness lab-node repmgr witness register -d "host=pg1-db port=5432 user=repmgr dbname=repmgr sslmode=verify-full sslrootcert=/etc/pg-tls/ca.crt" -F >/dev/null 2>&1 || true
    nexec witness lab-node resume-repmgrd
    ev "cluster_rebuilt_on_new_timeline"
}

heal() {
    local p
    p="$(current_primary || echo pg1)"
    [ "$(sql_node "$p" -c "select to_regclass('ledger_entries') is not null")" = "t" ] \
        || die "ledger_entries is still missing; the PITR step failed. Run 'lab reset' before continuing."
}
