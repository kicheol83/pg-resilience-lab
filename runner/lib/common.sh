set -o pipefail

LAB_ROOT=/lab
RESULTS=/lab/results
PREFIX="${LAB_PROJECT:-pglab}"
DATA_NODES="${DATA_NODES:-pg1 pg2 pg3}"
API_URL="${API_URL:-http://api:3000/v1}"
CA=/certs/ca.crt

ts() { date +%s.%3N; }
now_iso() { date -u +%Y-%m-%dT%H:%M:%S.%3NZ; }
say() { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
warn() { printf '\033[1;33m[%s] %s\033[0m\n' "$(date +%H:%M:%S)" "$*" >&2; }
die() { printf '\033[1;31m[%s] %s\033[0m\n' "$(date +%H:%M:%S)" "$*" >&2; exit 1; }

cname() { echo "$PREFIX-$1"; }

nexec() {
    local node="$1"
    shift
    docker exec "$(cname "$node")" "$@"
}

container_running() {
    [ "$(docker inspect -f '{{.State.Running}}' "$(cname "$1")" 2>/dev/null)" = "true" ]
}

agent() {
    local node="$1" path="${2:-/health}"
    curl -s -m 2 -o /dev/null -w '%{http_code}' "http://$node:8008$path" 2>/dev/null || echo 000
}

agent_json() {
    curl -s -m 2 "http://$1:8008/health" 2>/dev/null || echo "{\"node\":\"$1\",\"role\":\"unreachable\"}"
}

current_primary() {
    local n
    for n in $DATA_NODES; do
        if [ "$(agent "$n" /primary)" = "200" ]; then
            echo "$n"
            return 0
        fi
    done
    return 1
}

primary_count() {
    local n c=0
    for n in $DATA_NODES; do
        [ "$(agent "$n" /primary)" = "200" ] && c=$((c + 1))
    done
    echo "$c"
}

streaming_replicas() {
    local n c=0
    for n in $DATA_NODES; do
        [ "$(agent "$n" /replica)" = "200" ] && c=$((c + 1))
    done
    echo "$c"
}

conn() {
    local user="$1" host="${2:-haproxy}" port="${3:-5000}" db="${4:-ledgercore}"
    echo "host=$host port=$port dbname=$db user=$user sslmode=verify-full sslrootcert=$CA connect_timeout=3"
}

password_for() {
    case "$1" in
        ledger_owner) echo "$LEDGER_OWNER_PASSWORD" ;;
        ledger_app) echo "$LEDGER_APP_PASSWORD" ;;
        ledger_ro) echo "$LEDGER_RO_PASSWORD" ;;
        pgmonitor) echo "$PGMONITOR_PASSWORD" ;;
        repmgr) echo "$REPMGR_PASSWORD" ;;
    esac
}

sql_as() {
    local user="$1"
    shift
    PGPASSWORD="$(password_for "$user")" psql "$(conn "$user")" -X -Atq -v ON_ERROR_STOP=1 "$@"
}

sql_node() {
    local node="$1"
    shift
    nexec "$node" lab-node psql -d ledgercore -Atq "$@"
}

api_ready() {
    [ "$(curl -s -m 3 -o /dev/null -w '%{http_code}' "$API_URL/health/ready")" = "200" ]
}

api_write_ok() {
    local body
    body="$(curl -s -m 5 -X POST "$API_URL/users" -H 'Content-Type: application/json' \
        -d "{\"email\":\"probe-$(date +%s%N)@lab.test\"}" -o /dev/null -w '%{http_code}')"
    [ "$body" = "201" ]
}

wait_until() {
    local timeout="$1" i=0
    shift
    while ! "$@" >/dev/null 2>&1; do
        i=$((i + 1))
        [ "$i" -ge "$timeout" ] && return 1
        sleep 1
    done
}

haproxy_cmd() {
    echo "$*" | socat -T 3 - TCP:haproxy:9999 2>/dev/null
}

haproxy_backend_state() {
    haproxy_cmd "show stat" | awk -F, -v b="$1" '$1 == b && $2 != "BACKEND" && $2 != "FRONTEND" {print $2 "=" $18}' | tr '\n' ' '
}

collect_node_events() {
    local since="$1" out="$2" n
    : > "$out"
    for n in $DATA_NODES witness backup; do
        container_running "$n" || continue
        nexec "$n" cat /var/log/repmgr/events.log 2>/dev/null \
            | awk -F, -v s="$since" '$1 >= s' >> "$out" || true
    done
    sort -t, -k1,1n -o "$out" "$out"
}

repmgr_show() {
    local n out
    for n in witness $DATA_NODES; do
        container_running "$n" || continue
        out="$(nexec "$n" lab-node repmgr cluster show --compact 2>/dev/null || true)"
        if [ -n "$out" ]; then
            echo "(as seen from $n)"
            echo "$out"
            return 0
        fi
    done
    return 1
}
