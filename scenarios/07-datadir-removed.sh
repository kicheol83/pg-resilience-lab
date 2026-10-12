SCENARIO=07-datadir-removed
TITLE="Primary data directory deleted while running"
RECOVERY_TIMEOUT=240
inject() {
    nexec pg1 bash -c 'rm -rf "${PGDATA:?}"/*'
}
heal() {
    nexec pg1 lab-node rebuild >/dev/null
    ev "pg1_rebuilt"
}
