set -o pipefail

: "${NODE_NAME:?NODE_NAME is required}"
: "${NODE_ROLE:=data}"
: "${DATA_NODES:=pg1 pg2 pg3}"
: "${INITIAL_PRIMARY:=pg1}"
: "${LAB_STANZA:=ledger}"
: "${PG_DEFAULT_MAJOR:=17}"
: "${PGDATA:=/var/lib/postgresql/data/pgdata}"

LAB_VOLUME_ROOT="$(dirname "$PGDATA")"
LAB_MARKER="$LAB_VOLUME_ROOT/cluster.member"
PG_LOG=/var/log/postgresql/postgresql.log
REPMGR_CONF=/etc/repmgr/repmgr.conf
REPMGRD_LOG=/var/log/repmgr/repmgrd.log
EVENT_LOG=/var/log/repmgr/events.log
TLS_DIR=/etc/pg-tls
CA_FILE=$TLS_DIR/ca.crt

log() {
    printf '%s [lab:%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S.%3N %Z')" "$NODE_NAME" "$*" >&2
}

pg_major() {
    if [ -f "$PGDATA/PG_VERSION" ]; then
        cat "$PGDATA/PG_VERSION"
    else
        echo "$PG_DEFAULT_MAJOR"
    fi
}

pg_bin() {
    echo "/usr/lib/postgresql/$(pg_major)/bin"
}

as_pg() {
    if [ "$(id -u)" = "0" ]; then
        gosu postgres "$@"
    else
        "$@"
    fi
}

db_host() {
    echo "$1-db"
}

conninfo_for() {
    echo "host=$(db_host "$1") port=5432 user=repmgr dbname=repmgr connect_timeout=2 keepalives=1 keepalives_idle=5 keepalives_interval=2 keepalives_count=3 tcp_user_timeout=10000 sslmode=verify-full sslrootcert=$CA_FILE"
}

local_psql() {
    as_pg "$(pg_bin)/psql" -h /run/postgresql -U postgres -X -q -v ON_ERROR_STOP=1 "$@"
}

pg_running() {
    as_pg "$(pg_bin)/pg_ctl" -D "$PGDATA" status >/dev/null 2>&1
}

pg_accepting() {
    as_pg "$(pg_bin)/pg_isready" -h /run/postgresql -q -t 2 >/dev/null 2>&1
}

pg_start() {
    if pg_running; then
        return 0
    fi
    log "starting postgres $(pg_major)"
    as_pg "$(pg_bin)/pg_ctl" -D "$PGDATA" -l "$PG_LOG" -w -t 300 start >/dev/null
}

pg_stop() {
    local mode="${1:-fast}"
    if pg_running; then
        log "stopping postgres (mode=$mode)"
        if ! as_pg "$(pg_bin)/pg_ctl" -D "$PGDATA" -m "$mode" -w -t 60 stop >/dev/null 2>&1; then
            log "$mode shutdown did not finish in 60 s, escalating to immediate"
            as_pg "$(pg_bin)/pg_ctl" -D "$PGDATA" -m immediate -w -t 60 stop >/dev/null 2>&1 || true
        fi
    fi
}

is_standby_dir() {
    [ -f "$PGDATA/standby.signal" ]
}

remote_role() {
    as_pg "$(pg_bin)/psql" "$(conninfo_for "$1")" -X -Atq -c \
        "select case when pg_is_in_recovery() then 'standby' when current_setting('default_transaction_read_only') = 'on' then 'fenced' else 'primary' end, (select timeline_id from pg_control_checkpoint())" 2>/dev/null
}

find_primary() {
    local exclude="${1:-}" best="" best_tl=-1 n out role tl
    for n in $DATA_NODES; do
        [ "$n" = "$exclude" ] && continue
        out="$(remote_role "$n")" || continue
        role="${out%%|*}"
        tl="${out##*|}"
        if [ "$role" = "primary" ] && [ "${tl:-0}" -gt "$best_tl" ]; then
            best="$n"
            best_tl="$tl"
        fi
    done
    [ -n "$best" ] && echo "$best"
}

local_role() {
    if ! pg_accepting; then
        echo "down"
        return
    fi
    local_psql -Atc "select case when pg_is_in_recovery() then 'standby' when current_setting('default_transaction_read_only') = 'on' then 'fenced' else 'primary' end" 2>/dev/null || echo "unknown"
}

repmgr_cmd() {
    as_pg "$(pg_bin)/repmgr" -f "$REPMGR_CONF" "$@"
}

record_event() {
    printf '%s,%s,%s\n' "$(date +%s.%3N)" "$NODE_NAME" "$*" >> "$EVENT_LOG"
}
