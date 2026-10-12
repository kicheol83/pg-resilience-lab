SCENARIO=01-primary-stop
TITLE="Primary PostgreSQL stopped (pg_ctl stop -m fast)"
inject() {
    nexec pg1 lab-node stop fast
}
