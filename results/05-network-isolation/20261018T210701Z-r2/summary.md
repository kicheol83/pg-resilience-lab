# 05-network-isolation - Primary fully isolated from the network for 45 s

- run: `05-network-isolation-20261018T210701Z-r2` (2026-10-18T21:07:01.815Z)
- workload: 20 transfers/s, logical transfers 2841, acked 2560, gave up 281

| metric | value |
| --- | --- |
| RTO from injection | 32.03 s |
| client-observed write gap | 31.96 s |
| failed attempts | 14878 |
| acked after retry | 193 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 9.7 / 17.9 / 48.3 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -21.01 | workload_start |
| +0.00 | inject |
| +0.52 | node:pg1:repmgr:child_node_disconnect:success=1:node=1:witness node "witness" (ID: 4) has disconnected |
| +2.43 | node:pg2:repmgr:repmgrd_upstream_disconnect:success=1:node=2:unable to connect to upstream node "pg1" (ID: 1) |
| +2.74 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg1" (ID: 1) |
| +2.80 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg1" (ID: 1) |
| +10.73 | node:pg1:repmgr:child_node_disconnect:success=1:node=1:standby node "pg2" (ID: 2) has disconnected |
| +10.75 | node:pg1:repmgr:child_node_disconnect:success=1:node=1:standby node "pg3" (ID: 3) has disconnected |
| +19.54 | node:pg1:fenced_self_read_only |
| +19.55 | node:pg1:repmgr:child_nodes_disconnect_command:success=1:node=1:"child_nodes_disconnect_command" successfully executed |
| +25.58 | node:pg2:promote_requested |
| +28.78 | node:pg2:repmgr:standby_promote:success=1:node=2:server "pg2" (ID: 2) was successfully promoted to primary |
| +28.83 | node:pg2:promoted |
| +29.09 | node:pg2:repmgr:repmgrd_failover_promote:success=1:node=2:node "pg2" (ID: 2) promoted to primary; old primary "pg1" (ID: 1) marked as failed |
| +29.44 | node:pg2:repmgr:repmgrd_reload:success=1:node=2:monitoring cluster primary "pg2" (ID: 2) |
| +30.04 | node:witness:repmgr:repmgrd_failover_follow:success=1:node=4:witness node "witness" (ID: 4) now following new primary node "pg2" (ID: 2) |
| +30.17 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg2" (ID: 2) |
| +31.70 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new witness "witness" (ID: 4) has connected |
| +31.87 | node:pg2:wal_backfill:ok=41:failed=0 |
| +32.25 | node:pg3:repmgr:standby_follow:success=1:node=3:standby attached to upstream node "pg2" (ID: 2) |
| +32.31 | node:pg3:repmgr:repmgrd_failover_follow:success=1:node=3:node "pg3" (ID: 3) now following new upstream node "pg2" (ID: 2) |
| +33.86 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg3" (ID: 3) has connected |
| +45.78 | network_restored |
| +48.82 | pg1_after_reconnect_fenced |
| +48.84 | write_probe_ok |
| +48.91 | primary_now_pg2 |
| +129.59 | workload_done |
| +130.30 | node:pg1:repmgr:repmgrd_shutdown:success=1:node=1:TERM signal received |
| +133.65 | node:pg1:repmgr:node_rejoin:success=1:node=1:node 1 is now attached to node 2 |
| +133.65 | node:pg1:rejoined_to_pg2 |
| +134.07 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg1" (ID: 1) has connected |
| +136.15 | node:pg2:repmgr:repmgrd_local_disconnect:success=1:node=2:unable to connect to local node |
| +136.92 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg2" (ID: 2) |
| +137.07 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg2" (ID: 2) |
| +137.96 | node:pg1:repmgr:standby_promote:success=1:node=1:server "pg1" (ID: 1) was successfully promoted to primary |
| +138.31 | node:pg1:repmgr:standby_switchover:success=1:node=1:node "pg1" (ID: 1) promoted to primary, node "pg2" (ID: 2) demoted to standby |
| +139.21 | node:pg2:repmgr:repmgrd_local_reconnect:success=1:node=2:reconnected to local node after 3 seconds |
| +139.24 | node:pg2:repmgr:repmgrd_standby_reconnect:success=1:node=2:node has become a standby, monitoring connection to upstream node 1 |
| +139.55 | node:pg1:wal_backfill:ok=43:failed=0 |
| +139.96 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg1" (ID: 1) |
| +140.56 | healed |
