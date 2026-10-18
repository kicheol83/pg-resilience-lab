# 10-split-brain - Primary cut off from replicas and witness, still reachable by clients

- run: `10-split-brain-20261018T215826Z-r3` (2026-10-18T21:58:26.822Z)
- workload: 20 transfers/s, logical transfers 2839, acked 2637, gave up 202

| metric | value |
| --- | --- |
| RTO from injection | 28.2 s |
| client-observed write gap | 28.17 s |
| failed attempts | 11985 |
| acked after retry | 194 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 10.3 / 19.8 / 110.2 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -21.01 | workload_start |
| -19.49 | node:pg1:repmgr:child_node_new_connect:success=1:node=1:new witness "witness" (ID: 4) has connected |
| +0.00 | inject |
| +2.22 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg1" (ID: 1) |
| +2.25 | node:pg2:repmgr:repmgrd_upstream_disconnect:success=1:node=2:unable to connect to upstream node "pg1" (ID: 1) |
| +2.91 | node:pg1:repmgr:child_node_disconnect:success=1:node=1:witness node "witness" (ID: 4) has disconnected |
| +2.92 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg1" (ID: 1) |
| +6.31 | during_partition_primaries_0_pg1_primary |
| +15.07 | node:pg1:repmgr:child_node_disconnect:success=1:node=1:standby node "pg2" (ID: 2) has disconnected |
| +15.09 | node:pg1:repmgr:child_node_disconnect:success=1:node=1:standby node "pg3" (ID: 3) has disconnected |
| +20.47 | node:pg2:promote_requested |
| +23.63 | node:pg2:repmgr:standby_promote:success=1:node=2:server "pg2" (ID: 2) was successfully promoted to primary |
| +23.68 | node:pg2:promoted |
| +23.89 | node:pg2:repmgr:repmgrd_failover_promote:success=1:node=2:node "pg2" (ID: 2) promoted to primary; old primary "pg1" (ID: 1) marked as failed |
| +23.97 | node:pg2:repmgr:repmgrd_reload:success=1:node=2:monitoring cluster primary "pg2" (ID: 2) |
| +24.45 | node:witness:repmgr:repmgrd_failover_follow:success=1:node=4:witness node "witness" (ID: 4) now following new primary node "pg2" (ID: 2) |
| +24.85 | node:pg1:fenced_self_read_only |
| +24.87 | node:pg1:repmgr:child_nodes_disconnect_command:success=1:node=1:"child_nodes_disconnect_command" successfully executed |
| +25.71 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:reconnected to upstream node "pg2" (ID: 2) after 10 seconds, resuming monitoring |
| +26.23 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new witness "witness" (ID: 4) has connected |
| +26.75 | node:pg2:wal_backfill:ok=12:failed=0 |
| +28.64 | node:pg3:repmgr:standby_follow:success=1:node=3:standby attached to upstream node "pg2" (ID: 2) |
| +28.70 | node:pg3:repmgr:repmgrd_failover_follow:success=1:node=3:node "pg3" (ID: 3) now following new upstream node "pg2" (ID: 2) |
| +30.55 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg3" (ID: 3) has connected |
| +45.43 | before_heal_pg1_fenced_primary_pg2 |
| +45.57 | partition_healed |
| +45.59 | write_probe_ok |
| +45.66 | primary_now_pg2 |
| +129.65 | workload_done |
| +130.45 | node:pg1:repmgr:repmgrd_shutdown:success=1:node=1:TERM signal received |
| +133.84 | node:pg1:repmgr:node_rejoin:success=1:node=1:node 1 is now attached to node 2 |
| +133.84 | node:pg1:rejoined_to_pg2 |
| +134.82 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg1" (ID: 1) has connected |
| +136.67 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg2" (ID: 2) |
| +136.81 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg2" (ID: 2) |
| +136.88 | node:pg2:repmgr:repmgrd_local_disconnect:success=1:node=2:unable to connect to local node |
| +138.77 | node:pg1:repmgr:standby_promote:success=1:node=1:server "pg1" (ID: 1) was successfully promoted to primary |
| +138.94 | node:pg1:repmgr:repmgrd_start:success=1:node=1:monitoring cluster primary "pg1" (ID: 1) |
| +139.39 | node:pg1:wal_backfill:ok=16:failed=0 |
| +139.46 | node:pg1:repmgr:standby_switchover:success=1:node=1:node "pg1" (ID: 1) promoted to primary, node "pg2" (ID: 2) demoted to standby |
| +139.93 | node:pg2:repmgr:repmgrd_local_reconnect:success=1:node=2:reconnected to local node after 3 seconds |
| +140.00 | node:pg2:repmgr:repmgrd_standby_reconnect:success=1:node=2:node has become a standby, monitoring connection to upstream node 1 |
| +141.02 | node:pg1:repmgr:child_node_new_connect:success=1:node=1:new standby "pg2" (ID: 2) has connected |
| +141.06 | node:pg1:repmgr:child_node_new_connect:success=1:node=1:new standby "pg3" (ID: 3) has connected |
| +141.18 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg1" (ID: 1) |
| +141.93 | healed |
