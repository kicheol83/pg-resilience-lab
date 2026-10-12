SCENARIO=05-network-isolation
TITLE="Primary fully isolated from the network for 45 s"
ISOLATION_S="${ISOLATION_S:-45}"
inject() {
    net_disconnect pg1 db
    net_disconnect pg1 app
}
respond() {
    sleep "$ISOLATION_S"
    net_connect pg1 db
    net_connect pg1 app
    ev "network_restored"
    sleep 3
    ev "pg1_after_reconnect_$(node_role pg1)"
}
