cluster_state_line() {
    local n parts=()
    for n in $DATA_NODES; do
        parts+=("$n=$(agent_json "$n" | jq -r '.role' 2>/dev/null || echo '?')")
    done
    echo "${parts[*]} | haproxy[rw]: $(haproxy_backend_state pg_primary)"
}

cluster_healthy() {
    [ "$(primary_count)" = "1" ] && [ "$(streaming_replicas)" = "2" ] && api_ready && api_write_ok
}

wait_healthy() {
    local timeout="${1:-180}"
    if wait_until "$timeout" cluster_healthy; then
        return 0
    fi
    warn "cluster not healthy after ${timeout}s: $(cluster_state_line)"
    return 1
}

net_name() {
    case "$1" in
        db) echo "${PREFIX}_db" ;;
        app) echo "${PREFIX}_app" ;;
    esac
}

net_attached() {
    docker inspect -f "{{range \$k, \$v := .NetworkSettings.Networks}}{{\$k}} {{end}}" "$(cname "$1")" | tr ' ' '\n' | grep -qx "$(net_name "$2")"
}

net_ip_file() {
    echo "/tmp/lab-ip-$1-$2"
}

net_disconnect() {
    local node="$1" net="$2"
    net_attached "$node" "$net" || return 0
    docker inspect -f "{{(index .NetworkSettings.Networks \"$(net_name "$net")\").IPAddress}}" "$(cname "$node")" > "$(net_ip_file "$node" "$net")"
    docker network disconnect -f "$(net_name "$net")" "$(cname "$node")"
}

net_connect() {
    local node="$1" net="$2" ip=""
    local args=(--alias "$node")
    net_attached "$node" "$net" && return 0
    [ "$net" = "db" ] && args+=(--alias "$node-db")
    [ -s "$(net_ip_file "$node" "$net")" ] && ip="$(cat "$(net_ip_file "$node" "$net")")"
    if [ -n "$ip" ] && docker network connect "${args[@]}" --ip "$ip" "$(net_name "$net")" "$(cname "$node")" 2>/dev/null; then
        return 0
    fi
    docker network connect "${args[@]}" "$(net_name "$net")" "$(cname "$node")"
}

ensure_containers() {
    local c
    for c in $DATA_NODES witness backup haproxy redis api; do
        if ! container_running "$c"; then
            say "starting container $c"
            docker start "$(cname "$c")" >/dev/null
        fi
    done
}

ensure_networks() {
    local n
    for n in $DATA_NODES; do
        net_connect "$n" db
        net_connect "$n" app
    done
}

node_role() {
    agent_json "$1" | jq -r '.role' 2>/dev/null || echo unreachable
}

unpause_repmgrd() {
    local n
    for n in $DATA_NODES witness; do
        container_running "$n" || continue
        nexec "$n" lab-node resume-repmgrd >/dev/null 2>&1 || true
    done
    for n in $DATA_NODES witness; do
        if container_running "$n" && nexec "$n" lab-node repmgr service unpause >/dev/null 2>&1; then
            return 0
        fi
    done
}

any_writable_primary() {
    local n out
    for n in $DATA_NODES; do
        out="$(agent_json "$n" | jq -r '.role' 2>/dev/null)"
        [ "$out" = "primary" ] && { echo "$n"; return 0; }
    done
    return 1
}

promote_best_standby() {
    local n
    for n in $DATA_NODES; do
        if [ "$(node_role "$n")" = "standby" ]; then
            warn "no primary anywhere; promoting $n manually"
            nexec "$n" lab-node repmgr standby promote >/dev/null 2>&1 && return 0
        fi
    done
    return 1
}

heal_data_nodes() {
    local primary n role
    primary="$(current_primary || true)"
    if [ -z "$primary" ]; then
        warn "no healthy primary visible; making sure repmgrd is running and unpaused"
        unpause_repmgrd
        if ! wait_until 45 any_writable_primary; then
            promote_best_standby || true
        fi
        primary="$(any_writable_primary || true)"
        [ -n "$primary" ] || die "no primary: $(cluster_state_line)"
    fi
    for n in $DATA_NODES; do
        [ "$n" = "$primary" ] && continue
        role="$(node_role "$n")"
        if [ "$role" != "standby" ] || [ "$(agent "$n" /replica)" != "200" ]; then
            say "healing $n (role=$role) against primary $primary"
            if ! nexec "$n" lab-node rejoin "$primary" >/dev/null 2>&1; then
                warn "rejoin of $n failed, rebuilding from $primary"
                nexec "$n" lab-node rebuild "$primary" >/dev/null 2>&1 || die "could not rebuild $n"
            fi
        fi
    done
    wait_until 90 bash -c '[ "$(source /lab/runner/lib/common.sh; streaming_replicas)" = "2" ]' || warn "replicas not streaming yet: $(cluster_state_line)"
}

switchover_to() {
    local target="$1" primary attempt out
    for attempt in 1 2 3; do
        primary="$(current_primary || true)"
        [ "$primary" = "$target" ] && return 0
        say "switchover: $primary -> $target (attempt $attempt)"
        wait_until 60 bash -c "[ \"\$(source /lab/runner/lib/common.sh; agent $target /replica)\" = 200 ]" \
            || warn "$target is not streaming from $primary yet"
        if out="$(nexec "$target" lab-node repmgr standby switchover --siblings-follow --always-promote 2>&1)" \
            || out="$(nexec "$target" lab-node repmgr standby switchover --siblings-follow 2>&1)"; then
            if wait_until 60 bash -c "[ \"\$(source /lab/runner/lib/common.sh; current_primary)\" = \"$target\" ]"; then
                return 0
            fi
            warn "switchover to $target did not converge: $(cluster_state_line)"
        else
            warn "switchover to $target failed:"
            printf '%s\n' "$out" | tail -n 12 >&2
        fi
        heal_data_nodes
        sleep 10
    done
    die "switchover to $target failed after 3 attempts"
}

ensure_baseline() {
    say "restoring baseline (pg1 primary, pg2/pg3 streaming)"
    ensure_containers
    ensure_networks
    heal_data_nodes
    switchover_to pg1
    heal_data_nodes
    wait_healthy 180 || die "baseline not reached"
    say "baseline ok: $(cluster_state_line)"
}
