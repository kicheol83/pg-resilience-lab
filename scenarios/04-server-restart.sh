SCENARIO=04-server-restart
TITLE="Primary server restarted (docker restart)"
inject() {
    docker restart -t 30 "$(cname pg1)" >/dev/null
    ev "pg1_container_restarted"
}
respond() {
    wait_until 120 bash -c '[ "$(curl -s -m 2 -o /dev/null -w "%{http_code}" http://pg1:8008/health)" = "200" ]' || true
    ev "pg1_after_restart_$(node_role pg1)"
}
