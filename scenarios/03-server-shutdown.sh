SCENARIO=03-server-shutdown
TITLE="Primary server shut down (docker stop)"
inject() {
    docker stop -t 30 "$(cname pg1)" >/dev/null
}
heal() {
    docker start "$(cname pg1)" >/dev/null
    wait_until 120 bash -c '[ "$(curl -s -m 2 http://pg1:8008/health | jq -r .role 2>/dev/null)" = "standby" ]' || true
    ev "pg1_back_as_$(node_role pg1)"
}
