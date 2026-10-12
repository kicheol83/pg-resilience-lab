SCENARIO=06-disk-full
TITLE="Primary WAL volume runs out of space"
RECOVERY_TIMEOUT=240
WAL_FS=/pgwal-diskfull
HEADROOM_MB="${HEADROOM_MB:-24}"
before_run() {
    ensure_baseline
    say "moving pg1 WAL onto a 192 MB volume"
    switchover_to pg2
    nexec pg1 bash -c "rm -rf $WAL_FS/*"
    nexec pg1 lab-node rebuild pg2 --waldir "$WAL_FS" >/dev/null
    switchover_to pg1
    wait_healthy 120 || die "cluster not healthy after moving WAL"
}
inject() {
    local free_mb
    free_mb="$(nexec pg1 df -Pm "$WAL_FS" | awk 'NR==2 {print $4}')"
    meta_extra wal_fs_free_mb_before "$free_mb"
    nexec pg1 fallocate -l "$((free_mb - HEADROOM_MB))M" "$WAL_FS/ballast"
    ev "ballast_written_headroom_${HEADROOM_MB}MB"
    nexec pg1 lab-node psql -d ledgercore -c "insert into users (email) select 'bulk-' || g || '-' || extract(epoch from now())::bigint || '@lab.test' from generate_series(1, 300000) g" >/dev/null 2>&1 || true
    ev "bulk_write_attempted"
}
respond() {
    wait_until 60 bash -c '[ "$(curl -s -m 2 http://pg1:8008/health | jq -r .role)" != "primary" ]' || true
    ev "pg1_role_$(node_role pg1)"
}
heal() {
    nexec pg1 lab-node stop immediate || true
    nexec pg1 bash -c "rm -rf $WAL_FS/*"
    nexec pg1 lab-node rebuild >/dev/null
    ev "pg1_rebuilt_with_wal_back_in_pgdata"
}
