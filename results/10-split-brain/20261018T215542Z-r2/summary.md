# 10-split-brain - Primary cut off from replicas and witness, still reachable by clients

- run: `10-split-brain-20261018T215542Z-r2` (2026-10-18T21:55:42.507Z)
- workload: 20 transfers/s, logical transfers 2838, acked 2661, gave up 177

| metric | value |
| --- | --- |
| RTO from injection | 27.2 s |
| client-observed write gap | 27.13 s |
| failed attempts | 11119 |
| acked after retry | 196 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 9.9 / 18.4 / 77.1 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -21.02 | workload_start |
| -20.81 | node:pg1:repmgr:child_node_new_connect:success=1:node=1:new witness "witness" (ID: 4) has connected |
| +0.00 | inject |
| +2.66 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg1" (ID: 1) |
| +2.89 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg1" (ID: 1) |
| +3.06 | node:pg2:repmgr:repmgrd_upstream_disconnect:success=1:node=2:unable to connect to upstream node "pg1" (ID: 1) |
| +3.81 | node:pg1:repmgr:child_node_disconnect:success=1:node=1:witness node "witness" (ID: 4) has disconnected |
| +6.42 | during_partition_primaries_0_pg1_primary |
| +12.89 | node:pg1:repmgr:child_node_disconnect:success=1:node=1:standby node "pg2" (ID: 2) has disconnected |
| +12.90 | node:pg1:repmgr:child_node_disconnect:success=1:node=1:standby node "pg3" (ID: 3) has disconnected |
| +21.29 | node:pg2:promote_requested |
| +22.64 | node:pg1:fenced_self_read_only |
| +22.69 | node:pg1:repmgr:child_nodes_disconnect_command:success=1:node=1:"child_nodes_disconnect_command" successfully executed |
| +24.48 | node:pg2:repmgr:standby_promote:success=1:node=2:server "pg2" (ID: 2) was successfully promoted to primary |
| +24.60 | node:pg2:promoted |
| +24.86 | node:pg2:repmgr:repmgrd_failover_promote:success=1:node=2:node "pg2" (ID: 2) promoted to primary; old primary "pg1" (ID: 1) marked as failed |
| +24.94 | node:pg2:repmgr:repmgrd_reload:success=1:node=2:monitoring cluster primary "pg2" (ID: 2) |
| +25.79 | node:witness:repmgr:repmgrd_failover_follow:success=1:node=4:witness node "witness" (ID: 4) now following new primary node "pg2" (ID: 2) |
| +25.85 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg2" (ID: 2) |
| +27.01 | node:pg2:wal_backfill:ok=8:failed=0 |
| +27.23 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new witness "witness" (ID: 4) has connected |
| +27.23 | node:pg3:repmgr:standby_follow:success=1:node=3:standby attached to upstream node "pg2" (ID: 2) |
| +27.30 | node:pg3:repmgr:repmgrd_failover_follow:success=1:node=3:node "pg3" (ID: 3) now following new upstream node "pg2" (ID: 2) |
| +29.41 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg3" (ID: 3) has connected |
| +45.53 | before_heal_pg1_fenced_primary_pg2 |
| +45.65 | partition_healed |
| +45.67 | write_probe_ok |
| +45.74 | primary_now_pg2 |
| +129.73 | workload_done |
| +130.41 | node:pg1:repmgr:repmgrd_shutdown:success=1:node=1:TERM signal received |
| +133.17 | node:pg1:repmgr:node_rejoin:success=1:node=1:node 1 is now attached to node 2 |
| +133.18 | node:pg1:rejoined_to_pg2 |
| +133.57 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg1" (ID: 1) has connected |
| +135.68 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg2" (ID: 2) |
| +135.69 | node:pg2:repmgr:repmgrd_local_disconnect:success=1:node=2:unable to connect to local node |
| +136.44 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg2" (ID: 2) |
| +137.46 | node:pg1:repmgr:standby_promote:success=1:node=1:server "pg1" (ID: 1) was successfully promoted to primary |
| +137.91 | node:pg1:wal_backfill:ok=12:failed=0 |
| +138.17 | node:pg1:repmgr:standby_switchover:success=1:node=1:node "pg1" (ID: 1) promoted to primary, node "pg2" (ID: 2) demoted to standby |
| +138.73 | node:pg2:repmgr:repmgrd_local_reconnect:success=1:node=2:reconnected to local node after 3 seconds |
| +138.75 | node:pg2:repmgr:repmgrd_standby_reconnect:success=1:node=2:node has become a standby, monitoring connection to upstream node 1 |
| +138.78 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg1" (ID: 1) |
| +140.36 | healed |
