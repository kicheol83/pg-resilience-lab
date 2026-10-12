#!/usr/bin/env bash
set -euo pipefail
. /lab/runner/lib/common.sh
. /lab/runner/lib/cluster.sh
. /lab/runner/lib/scenario.sh

OLD=17
NEW=18
mode="${1:-run}"
VOLROOT=/var/lib/postgresql/data
NEWDATA="$VOLROOT/pgdata$NEW"

on() {
    local node="$1"
    shift
    docker exec -u postgres -w /var/lib/postgresql "$(cname "$node")" bash -c "$*"
}

prepare_new_cluster() {
    local node="$1"
    on "$node" "rm -rf $NEWDATA && /usr/lib/postgresql/$NEW/bin/initdb -D $NEWDATA -U postgres --data-checksums --encoding=UTF8 --locale=C.UTF-8 --auth-local=peer --auth-host=scram-sha-256 >/dev/null && echo \"include '/etc/lab/postgresql.lab.conf'\" >> $NEWDATA/postgresql.conf"
}

upgrade_check() {
    local primary
    primary="$(current_primary)" || die "no primary"
    docker exec "$(cname "$primary")" test -x "/usr/lib/postgresql/$NEW/bin/pg_upgrade" || die "PostgreSQL $NEW binaries are not in the image (build with INSTALL_PG18=true)"
    prepare_new_cluster "$primary"
    on "$primary" "cd /tmp && /usr/lib/postgresql/$NEW/bin/pg_upgrade --check -b /usr/lib/postgresql/$OLD/bin -B /usr/lib/postgresql/$NEW/bin -d \$PGDATA -D $NEWDATA"
    on "$primary" "rm -rf $NEWDATA"
}

rollback_old() {
    local n
    warn "rolling back: starting the PostgreSQL $OLD cluster again"
    on pg1 "rm -rf $NEWDATA"
    for n in pg1 pg2 pg3; do nexec "$n" lab-node start >/dev/null 2>&1 || true; done
    for n in pg1 pg2 pg3 witness; do nexec "$n" lab-node resume-repmgrd >/dev/null 2>&1 || true; done
    stop_workload
}

upgrade_run() {
    ensure_baseline
    RUN_DIR="$RESULTS/upgrade-pg-upgrade/$(date -u +%Y%m%dT%H%M%SZ)"
    mkdir -p "$RUN_DIR"
    : > "$RUN_DIR/events.csv"
    SCENARIO=upgrade-pg-upgrade
    TITLE="Major upgrade $OLD -> $NEW with pg_upgrade --link (whole repmgr cluster)"
    RATE="${LAB_RATE:-20}"
    DURATION="${LAB_DURATION:-240s}"
    local run_id="upgrade-$(date +%s)"
    write_meta "$run_id" 1
    RUN_START="$(ts)"

    ev "pre_upgrade_full_backup_start"
    nexec backup gosu postgres pgbackrest --stanza=ledger --type=full backup >/dev/null
    ev "pre_upgrade_full_backup_done"
    prepare_new_cluster pg1

    ev "workload_start"
    start_workload "$run_id" "$DURATION" "$RATE"
    sleep 20

    local n
    for n in pg1 pg2 pg3 witness; do nexec "$n" lab-node pause-repmgrd; done
    nexec pg2 lab-node stop fast
    nexec pg3 lab-node stop fast
    ev "standbys_stopped"
    ev "inject"
    nexec pg1 lab-node stop fast
    ev "old_primary_stopped"
    local t0
    t0="$(ts)"
    on pg1 "cd /tmp && /usr/lib/postgresql/$NEW/bin/pg_upgrade --link --jobs=2 -b /usr/lib/postgresql/$OLD/bin -B /usr/lib/postgresql/$NEW/bin -d \$PGDATA -D $NEWDATA -O \"-c credcheck.encrypted_password_allowed=on\"" > "$RUN_DIR/pg_upgrade.log" 2>&1 \
        || { tail -n 30 "$RUN_DIR/pg_upgrade.log" >&2; rollback_old; die "pg_upgrade failed; the PostgreSQL $OLD cluster was restarted unchanged"; }
    meta_extra pg_upgrade_s "$(awk "BEGIN{printf \"%.1f\", $(ts) - $t0}")"
    ev "pg_upgrade_done"
    on pg1 "mv \$PGDATA $VOLROOT/pgdata$OLD.old && mv $NEWDATA \$PGDATA"
    nexec pg1 lab-node start
    ev "new_primary_started_pg$NEW"
    nexec backup gosu postgres pgbackrest --stanza=ledger stanza-upgrade >/dev/null
    ev "pgbackrest_stanza_upgraded"
    nexec pg1 lab-node psql -d repmgr -c "ALTER EXTENSION repmgr UPDATE" >/dev/null || true
    nexec pg1 lab-node repmgr primary register -F >/dev/null 2>&1
    nexec pg1 lab-node resume-repmgrd
    for n in pg2 pg3; do
        nexec "$n" lab-node rebuild pg1 >/dev/null
        ev "${n}_recloned_on_pg$NEW"
    done
    nexec witness lab-node resume-repmgrd
    nexec pg1 lab-node psql -d ledgercore -c "select 1" >/dev/null
    stop_workload
    ev "workload_done"
    nexec backup gosu postgres pgbackrest --stanza=ledger --type=full backup >/dev/null
    ev "post_upgrade_full_backup_done"
    on pg1 "rm -rf $VOLROOT/pgdata$OLD.old"
    wait_healthy 180 || warn "cluster not fully healthy after upgrade"
    ev "server_version_$(sql_node pg1 -c 'show server_version' | cut -d' ' -f1)"
    collect_node_events "$RUN_START" "$RUN_DIR/node-events.csv"
    awk -F, 'BEGIN{OFS=","} {t=$1; n=$2; $1=""; $2=""; sub(/^,,/, ""); print t, "node:" n ":" $0}' "$RUN_DIR/node-events.csv" >> "$RUN_DIR/events.csv"
    sort -t, -k1,1n -o "$RUN_DIR/events.csv" "$RUN_DIR/events.csv"
    gzip -f "$RUN_DIR/k6.json"
    python3 /lab/measure/analyze.py "$RUN_DIR" | tee "$RUN_DIR/analyze.log"
    python3 /lab/measure/report.py "$RESULTS" >/dev/null
}

case "$mode" in
    check) upgrade_check ;;
    run) upgrade_run ;;
esac
