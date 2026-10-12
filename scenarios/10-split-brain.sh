SCENARIO=10-split-brain
TITLE="Primary cut off from replicas and witness, still reachable by clients"
PARTITION_S="${PARTITION_S:-45}"
inject() {
    net_disconnect pg1 db
}
respond() {
    sleep 6
    ev "during_partition_primaries_$(primary_count)_pg1_$(node_role pg1)"
    sleep "$((PARTITION_S - 6))"
    ev "before_heal_pg1_$(node_role pg1)_primary_$(current_primary || echo none)"
    net_connect pg1 db
    ev "partition_healed"
}
