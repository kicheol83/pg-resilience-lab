SCENARIO=08-relfile-removed
TITLE="Primary loses the data file of table accounts"
RECOVERY_TIMEOUT=240
inject() {
    local path
    path="$(sql_node pg1 -c "select pg_relation_filepath('accounts')")"
    meta_extra relation_file "$path"
    sql_node pg1 -c "checkpoint" >/dev/null
    sql_node pg1 -c "select count(pg_buffercache_evict(bufferid)) from pg_buffercache where relfilenode = pg_relation_filenode('accounts')" >/dev/null || true
    nexec pg1 bash -c "rm -f \"\$PGDATA/$path\" \"\$PGDATA/$path\"_fsm \"\$PGDATA/$path\"_vm"
    sql_node pg1 -c "select count(pg_buffercache_evict(bufferid)) from pg_buffercache where relfilenode = pg_relation_filenode('accounts')" >/dev/null 2>&1 || true
}
respond() {
    wait_until 60 bash -c "source /lab/runner/lib/common.sh; ! sql_node pg1 -c 'select count(*) from accounts' >/dev/null 2>&1" || true
    ev "detected_by_synthetic_check"
    nexec pg1 lab-node stop immediate
    ev "operator_stopped_corrupted_primary"
}
heal() {
    nexec pg1 lab-node rebuild >/dev/null 2>&1
    ev "pg1_rebuilt"
}
