. /usr/local/bin/lab-common.sh

PIDS=()

install_tls() {
    local src=/certs
    for _ in $(seq 1 60); do
        [ -f "$src/$NODE_NAME.crt" ] && break
        log "waiting for certificates"
        sleep 1
    done
    install -o postgres -g postgres -m 0644 "$src/ca.crt" "$TLS_DIR/ca.crt"
    install -o postgres -g postgres -m 0644 "$src/$NODE_NAME.crt" "$TLS_DIR/node.crt"
    install -o postgres -g postgres -m 0600 "$src/$NODE_NAME.key" "$TLS_DIR/node.key"
}

install_ssh() {
    local home=/var/lib/postgresql
    chmod 0755 "$home"
    install -d -o postgres -g postgres -m 0700 "$home/.ssh"
    install -o postgres -g postgres -m 0600 /certs/ssh/id_ed25519 "$home/.ssh/id_ed25519"
    install -o postgres -g postgres -m 0644 /certs/ssh/id_ed25519.pub "$home/.ssh/id_ed25519.pub"
    install -o postgres -g postgres -m 0600 /certs/ssh/id_ed25519.pub "$home/.ssh/authorized_keys"
    cat > "$home/.ssh/config" <<EOF
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
    ConnectTimeout 5
EOF
    chown postgres:postgres "$home/.ssh/config"
    chmod 0600 "$home/.ssh/config"
    ssh-keygen -A >/dev/null 2>&1
    cat > /etc/ssh/sshd_config.d/lab.conf <<EOF
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AllowUsers postgres
EOF
    /usr/sbin/sshd -e
}

write_pgpass() {
    local file=/var/lib/postgresql/.pgpass
    printf '*:*:*:repmgr:%s\n' "$REPMGR_PASSWORD" > "$file"
    chown postgres:postgres "$file"
    chmod 0600 "$file"
}

render_repmgr_conf() {
    local bin node_id priority
    bin="$(pg_bin)"
    node_id="${NODE_ID:?NODE_ID is required}"
    priority="${PRIORITY:-100}"
    local basebackup_opts="--checkpoint=fast"
    if [ -n "${PG_WAL_DIR:-}" ]; then
        basebackup_opts="$basebackup_opts --waldir=$PG_WAL_DIR/pg_wal"
    fi
    cat > "$REPMGR_CONF" <<EOF
node_id=$node_id
node_name='$NODE_NAME'
conninfo='$(conninfo_for "$NODE_NAME")'
data_directory='$PGDATA'
pg_bindir='$bin'
replication_user='repmgr'
use_replication_slots=yes
location='seoul-lab'
priority=$priority
failover='automatic'
promote_command='/usr/local/bin/repmgr-promote'
follow_command='$bin/repmgr standby follow -f $REPMGR_CONF --log-to-file --upstream-node-id=%n'
monitor_interval_secs=1
reconnect_attempts=4
reconnect_interval=1
connection_check_type='ping'
standby_disconnect_on_failover=yes
primary_visibility_consensus=yes
election_rerun_interval=5
sibling_nodes_disconnect_timeout=30
child_nodes_check_interval=2
child_nodes_connected_min_count=1
child_nodes_disconnect_timeout=8
child_nodes_connected_include_witness=yes
child_nodes_disconnect_command='/usr/local/bin/fence-self'
degraded_monitoring_timeout=-1
log_level='INFO'
log_facility='STDERR'
log_file='$REPMGRD_LOG'
log_status_interval=60
event_notification_command='/usr/local/bin/repmgr-event %n %e %s "%t" "%d"'
ssh_options='-q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5'
service_start_command='$bin/pg_ctl -D $PGDATA -l $PG_LOG -w -t 300 start'
service_stop_command='$bin/pg_ctl -D $PGDATA -m fast -w -t 120 stop'
service_restart_command='$bin/pg_ctl -D $PGDATA -l $PG_LOG -m fast -w -t 300 restart'
service_reload_command='$bin/pg_ctl -D $PGDATA reload'
repmgrd_pid_file='/run/repmgr/repmgrd.pid'
pg_basebackup_options='$basebackup_opts'
EOF
    chown postgres:postgres "$REPMGR_CONF"
}

render_pgbackrest_node_conf() {
    cat > /etc/pgbackrest/pgbackrest.conf <<EOF
[global]
repo1-host=backup-db
repo1-host-type=tls
repo1-host-ca-file=$CA_FILE
repo1-host-cert-file=$TLS_DIR/node.crt
repo1-host-key-file=$TLS_DIR/node.key
tls-server-address=*
tls-server-ca-file=$CA_FILE
tls-server-cert-file=$TLS_DIR/node.crt
tls-server-key-file=$TLS_DIR/node.key
tls-server-auth=backup=$LAB_STANZA
archive-async=y
spool-path=/var/spool/pgbackrest
process-max=2
log-level-console=warn
log-level-file=detail
log-path=/var/log/pgbackrest

[$LAB_STANZA]
pg1-path=$PGDATA
pg1-socket-path=/run/postgresql
EOF
    chown postgres:postgres /etc/pgbackrest/pgbackrest.conf
}

render_pgbackrest_repo_conf() {
    local i=1 n
    {
        cat <<EOF
[global]
repo1-path=/var/lib/pgbackrest
repo1-retention-full=2
repo1-retention-diff=4
repo1-bundle=y
repo1-block=y
start-fast=y
compress-type=zst
process-max=2
backup-standby=prefer
archive-check=y
log-level-console=info
log-level-file=detail
log-path=/var/log/pgbackrest
tls-server-address=*
tls-server-ca-file=$CA_FILE
tls-server-cert-file=$TLS_DIR/node.crt
tls-server-key-file=$TLS_DIR/node.key
EOF
        for n in $DATA_NODES; do
            echo "tls-server-auth=$n=$LAB_STANZA"
        done
        if [ -n "${S3_BUCKET:-}" ]; then
            cat <<EOF
repo2-type=s3
repo2-path=/pgbackrest/${S3_PREFIX:-pg-resilience-lab}
repo2-s3-bucket=$S3_BUCKET
repo2-s3-region=${S3_REGION:-ap-northeast-2}
repo2-s3-endpoint=${S3_ENDPOINT:-s3.${S3_REGION:-ap-northeast-2}.amazonaws.com}
repo2-s3-key=$S3_KEY
repo2-s3-key-secret=$S3_KEY_SECRET
repo2-retention-full=4
repo2-bundle=y
repo2-block=y
repo2-cipher-type=aes-256-cbc
repo2-cipher-pass=${S3_CIPHER_PASS:?S3_CIPHER_PASS is required when S3_BUCKET is set}
EOF
        fi
        echo
        echo "[$LAB_STANZA]"
        for n in $DATA_NODES; do
            cat <<EOF
pg$i-host=$(db_host "$n")
pg$i-host-type=tls
pg$i-host-ca-file=$CA_FILE
pg$i-host-cert-file=$TLS_DIR/node.crt
pg$i-host-key-file=$TLS_DIR/node.key
pg$i-path=$PGDATA
pg$i-socket-path=/run/postgresql
EOF
            i=$((i + 1))
        done
    } > /etc/pgbackrest/pgbackrest.conf
    chown postgres:postgres /etc/pgbackrest/pgbackrest.conf
    chmod 0640 /etc/pgbackrest/pgbackrest.conf
}

supervise() {
    local name="$1"
    shift
    (
        while true; do
            "$@" >> "/var/log/lab-$name.log" 2>&1 || true
            sleep 2
        done
    ) &
    PIDS+=("$!")
}

run_repmgrd() {
    if [ -f /run/repmgr/stop ] || [ -f /run/repmgr/watchdog-busy ] || ! pg_accepting || [ ! -f "$PGDATA/PG_VERSION" ]; then
        sleep 2
        return 0
    fi
    if ! repmgr_cmd node status >/dev/null 2>&1 && [ "$NODE_ROLE" = "data" ]; then
        sleep 2
        return 0
    fi
    render_repmgr_conf
    if [ "$NODE_ROLE" = "data" ] && is_standby_dir; then
        follow_if_orphaned
    fi
    as_pg "$(pg_bin)/repmgrd" -f "$REPMGR_CONF" --daemonize=false
}

upstream_name() {
    grep '^primary_conninfo' "$PGDATA/postgresql.auto.conf" 2>/dev/null | tail -n 1 \
        | grep -oE "host='*[a-z0-9]+-db" | sed -E "s/host='*//; s/-db\$//"
}

follow_if_orphaned() {
    local upstream primary
    upstream="$(upstream_name)"
    [ -n "$upstream" ] || return 0
    if remote_role "$upstream" >/dev/null; then
        return 0
    fi
    primary="$(find_primary "$NODE_NAME" || true)"
    if [ -n "$primary" ] && [ "$primary" != "$upstream" ]; then
        log "upstream $upstream is unreachable and $primary is primary; following $primary"
        record_event "auto_follow_$primary"
        repmgr_cmd standby follow --log-to-file >/dev/null 2>&1 || log "standby follow failed"
    fi
}

run_watchdog() {
    sleep 5
    local marker=/run/repmgr/not-streaming-since since age primary
    if [ -f /run/repmgr/stop ] || [ "${AUTO_REJOIN:-true}" != "true" ] || ! is_standby_dir || ! pg_accepting; then
        rm -f "$marker"
        return 0
    fi
    if [ "$(local_psql -d postgres -Atc "select coalesce((select status from pg_stat_wal_receiver limit 1), 'none')" 2>/dev/null)" = "streaming" ]; then
        rm -f "$marker"
        return 0
    fi
    [ -f "$marker" ] || date +%s > "$marker"
    since="$(cat "$marker")"
    age=$(( $(date +%s) - since ))
    [ "$age" -ge "${AUTO_REJOIN_AFTER_S:-20}" ] || return 0
    primary="$(find_primary "$NODE_NAME" || true)"
    [ -n "$primary" ] || return 0
    log "watchdog: not streaming for ${age}s while $primary is primary; repairing"
    touch /run/repmgr/watchdog-busy
    pkill -TERM -x repmgrd 2>/dev/null || true
    if repmgr_cmd standby follow --log-to-file >> /var/log/repmgr/watchdog.log 2>&1 \
        && sleep 3 && [ "$(local_psql -d postgres -Atc "select coalesce((select status from pg_stat_wal_receiver limit 1), 'none')" 2>/dev/null)" = "streaming" ]; then
        record_event "watchdog_follow_$primary"
    else
        record_event "watchdog_rejoin_with_rewind_$primary"
        rejoin_to "$primary" >> /var/log/repmgr/watchdog.log 2>&1 || true
    fi
    rm -f /run/repmgr/watchdog-busy "$marker"
}

run_agent() {
    as_pg socat -T 3 TCP-LISTEN:8008,reuseaddr,fork SYSTEM:/usr/local/bin/pg-health-agent
}

run_pgbackrest_server() {
    as_pg pgbackrest server
}

init_primary() {
    log "bootstrapping a new cluster on $NODE_NAME"
    local waldir_opt=()
    if [ -n "${PG_WAL_DIR:-}" ]; then
        install -d -o postgres -g postgres -m 0700 "$PG_WAL_DIR"
        waldir_opt=(--waldir="$PG_WAL_DIR/pg_wal")
    fi
    install -d -o postgres -g postgres -m 0700 "$PGDATA"
    as_pg "$(pg_bin)/initdb" -D "$PGDATA" -U postgres --data-checksums --encoding=UTF8 --locale=C.UTF-8 \
        --auth-local=peer --auth-host=scram-sha-256 "${waldir_opt[@]}" >/dev/null
    echo "include '/etc/lab/postgresql.lab.conf'" >> "$PGDATA/postgresql.conf"
    pg_start
    export PGOPTIONS='-c synchronous_commit=local'
    local_psql -d postgres -f /etc/lab/sql/bootstrap.sql >/dev/null
    local_psql -d repmgr -c "CREATE EXTENSION IF NOT EXISTS repmgr" >/dev/null
    render_repmgr_conf
    repmgr_cmd primary register -F >/dev/null
    unset PGOPTIONS
    record_event "bootstrap_primary"
}

clone_from() {
    local primary="$1" upstream_major
    upstream_major="$(as_pg psql "$(conninfo_for "$primary")" -X -Atq -c "select current_setting('server_version_num')::int / 10000" 2>/dev/null || true)"
    if [ -n "$upstream_major" ] && [ -d "/usr/lib/postgresql/$upstream_major/bin" ]; then
        export PG_DEFAULT_MAJOR="$upstream_major"
    fi
    log "cloning $NODE_NAME from $primary (PostgreSQL $PG_DEFAULT_MAJOR)"
    install -d -o postgres -g postgres -m 0700 "$PGDATA"
    find "$PGDATA" -mindepth 1 -delete 2>/dev/null || true
    if [ -n "${PG_WAL_DIR:-}" ]; then
        install -d -o postgres -g postgres -m 0700 "$PG_WAL_DIR"
        rm -rf "${PG_WAL_DIR:?}/pg_wal"
    fi
    render_repmgr_conf
    repmgr_cmd -d "$(conninfo_for "$primary")" standby clone --fast-checkpoint -F >> /var/log/repmgr/clone.log 2>&1
    strip_recovery_targets
    pg_start
    repmgr_cmd standby register -F --wait-sync=30 >> /var/log/repmgr/clone.log 2>&1 || repmgr_cmd standby register -F >> /var/log/repmgr/clone.log 2>&1
    record_event "cloned_from_$primary"
}

strip_recovery_targets() {
    sed -i -E '/^recovery_target(_xid|_time|_name|_lsn|_inclusive|_action)? *=/d' "$PGDATA/postgresql.auto.conf" 2>/dev/null || true
}

ensure_clean_shutdown() {
    local state
    state="$(as_pg "$(pg_bin)/pg_controldata" "$PGDATA" 2>/dev/null | sed -n 's/^Database cluster state: *//p')"
    case "$state" in
        "shut down"|"shut down in recovery"|"")
            ;;
        *)
            log "data directory state is '$state'; running single-user crash recovery first"
            rm -f "$PGDATA/postmaster.pid"
            echo "" | as_pg "$(pg_bin)/postgres" --single -D "$PGDATA" -c archive_mode=off postgres >/dev/null 2>&1 || true
            ;;
    esac
}

rejoin_to() {
    local primary="$1"
    log "rejoining $NODE_NAME to $primary with pg_rewind"
    pg_stop fast
    ensure_clean_shutdown
    sed -i '/default_transaction_read_only/d' "$PGDATA/postgresql.auto.conf" 2>/dev/null || true
    strip_recovery_targets
    render_repmgr_conf
    if repmgr_cmd node rejoin -d "$(conninfo_for "$primary")" --force-rewind --verbose >> /var/log/repmgr/rejoin.log 2>&1; then
        record_event "rejoined_to_$primary"
        return 0
    fi
    log "rejoin failed, falling back to a fresh clone"
    record_event "rejoin_failed_fallback_clone"
    pg_stop immediate
    clone_from "$primary"
}

start_data_node() {
    if [ -f "$PGDATA/PG_VERSION" ]; then
        if is_standby_dir; then
            pg_start
            return
        fi
        local other
        other="$(find_primary "$NODE_NAME" || true)"
        if [ -n "$other" ]; then
            log "another primary ($other) is active; this node must not start as primary"
            record_event "boot_guard_detected_primary_$other"
            rejoin_to "$other"
        else
            pg_start
        fi
        return
    fi
    local primary
    while true; do
        primary="$(find_primary "$NODE_NAME" || true)"
        if [ -n "$primary" ]; then
            clone_from "$primary"
            break
        fi
        if [ "$NODE_NAME" = "$INITIAL_PRIMARY" ] && [ ! -f "$LAB_MARKER" ]; then
            init_primary
            break
        fi
        log "waiting for a primary to clone from"
        sleep 2
    done
    touch "$LAB_MARKER"
    chown postgres:postgres "$LAB_MARKER"
}

start_witness() {
    if [ ! -f "$PGDATA/PG_VERSION" ]; then
        install -d -o postgres -g postgres -m 0700 "$PGDATA"
        as_pg "$(pg_bin)/initdb" -D "$PGDATA" -U postgres --encoding=UTF8 --locale=C.UTF-8 \
            --auth-local=peer --auth-host=scram-sha-256 >/dev/null
        echo "include '/etc/lab/postgresql.witness.conf'" >> "$PGDATA/postgresql.conf"
        pg_start
        printf '%s\n' '\getenv pw REPMGR_PASSWORD' "CREATE ROLE repmgr WITH LOGIN SUPERUSER PASSWORD :'pw';" 'CREATE DATABASE repmgr OWNER repmgr;' \
            | local_psql -d postgres >/dev/null
        local_psql -d repmgr -c "CREATE EXTENSION IF NOT EXISTS repmgr" >/dev/null
    else
        pg_start
    fi
    render_repmgr_conf
    local primary
    until primary="$(find_primary)"; do
        log "witness waiting for a primary"
        sleep 2
    done
    repmgr_cmd witness register -d "$(conninfo_for "$primary")" -F >/dev/null
    record_event "witness_registered_with_$primary"
}

start_standalone() {
    export PG_DEFAULT_MAJOR="${STANDALONE_MAJOR:-18}"
    if [ ! -f "$PGDATA/PG_VERSION" ]; then
        install -d -o postgres -g postgres -m 0700 "$PGDATA"
        as_pg "$(pg_bin)/initdb" -D "$PGDATA" -U postgres --data-checksums --encoding=UTF8 --locale=C.UTF-8 \
            --auth-local=peer --auth-host=scram-sha-256 >/dev/null
        echo "include '/etc/lab/postgresql.lab.conf'" >> "$PGDATA/postgresql.conf"
        {
            echo "synchronous_standby_names = ''"
            echo "archive_mode = off"
        } >> "$PGDATA/postgresql.auto.conf"
        pg_start
        local_psql -d postgres -f /etc/lab/sql/bootstrap.sql >/dev/null
        local_psql -d repmgr -c "CREATE EXTENSION IF NOT EXISTS repmgr" >/dev/null
        record_event "bootstrap_standalone_$(pg_major)"
    else
        pg_start
    fi
}

start_backup_host() {
    render_pgbackrest_repo_conf
    supervise pgbackrest-server run_pgbackrest_server
    until as_pg pgbackrest --stanza="$LAB_STANZA" stanza-create >/dev/null 2>&1; do
        log "waiting for the cluster before stanza-create"
        sleep 3
    done
    as_pg pgbackrest --stanza="$LAB_STANZA" check >/dev/null 2>&1 || log "pgbackrest check reported a problem, see /var/log/pgbackrest"
    if ! as_pg pgbackrest --stanza="$LAB_STANZA" info --output=json | grep -q '"label"'; then
        log "taking the first full backup"
        as_pg pgbackrest --stanza="$LAB_STANZA" --type=full backup >/dev/null
    fi
    cat > /etc/cron.d/pgbackrest <<EOF
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin
${BACKUP_CRON_FULL:-0 3 * * 0} postgres pgbackrest --stanza=$LAB_STANZA --type=full backup >> /var/log/pgbackrest/cron.log 2>&1
${BACKUP_CRON_DIFF:-0 3 * * 1-6} postgres pgbackrest --stanza=$LAB_STANZA --type=diff backup >> /var/log/pgbackrest/cron.log 2>&1
${BACKUP_CRON_INCR:-0 */4 * * *} postgres pgbackrest --stanza=$LAB_STANZA --type=incr backup >> /var/log/pgbackrest/cron.log 2>&1
${RESTORE_VERIFY_CRON:-30 4 * * *} postgres /usr/local/bin/restore-verify >> /var/log/pgbackrest/verify.log 2>&1
EOF
    chmod 0644 /etc/cron.d/pgbackrest
    printenv | grep -E '^(NODE_|LAB_|DATA_NODES|PGDATA|PATH)=' > /etc/environment || true
    cron
    record_event "backup_host_ready"
}

shutdown() {
    log "shutdown requested"
    touch /run/repmgr/stop
    pkill -TERM -x repmgrd 2>/dev/null || true
    if [ "$NODE_ROLE" != "backup" ]; then
        pg_stop fast
    fi
    for p in "${PIDS[@]}"; do
        kill "$p" 2>/dev/null || true
    done
    exit 0
}

main() {
    trap shutdown TERM INT
    rm -f /run/repmgr/stop
    touch "$PG_LOG" "$REPMGRD_LOG" "$EVENT_LOG"
    chown postgres:postgres "$PG_LOG" "$REPMGRD_LOG" "$EVENT_LOG"
    install -d -o postgres -g postgres -m 0700 "$LAB_VOLUME_ROOT"
    install_tls
    write_pgpass
    case "$NODE_ROLE" in
        data)
            install_ssh
            render_pgbackrest_node_conf
            start_data_node
            supervise agent run_agent
            supervise pgbackrest-server run_pgbackrest_server
            supervise repmgrd run_repmgrd
            supervise watchdog run_watchdog
            ;;
        witness)
            install_ssh
            start_witness
            supervise repmgrd run_repmgrd
            ;;
        backup)
            install_ssh
            start_backup_host
            ;;
        standalone)
            start_standalone
            supervise agent run_agent
            ;;
        *)
            log "unknown NODE_ROLE=$NODE_ROLE"
            exit 1
            ;;
    esac
    record_event "node_ready"
    log "node ready"
    tail -n 0 -F "$PG_LOG" "$REPMGRD_LOG" "$EVENT_LOG" /var/log/repmgr/rejoin.log 2>/dev/null &
    PIDS+=("$!")
    while true; do
        sleep 3600 &
        wait $! || true
    done
}
