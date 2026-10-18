# 05-network-isolation - Primary fully isolated from the network for 45 s

- run: `05-network-isolation-20261018T210416Z-r1` (2026-10-18T21:04:16.068Z)
- workload: 20 transfers/s, logical transfers 2833, acked 2650, gave up 183

| metric | value |
| --- | --- |
| RTO from injection | 27.91 s |
| client-observed write gap | 27.85 s |
| failed attempts | 11231 |
| acked after retry | 199 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 9.6 / 19.6 / 226.1 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -21.01 | workload_start |
| +0.00 | inject |
| +2.15 | node:pg1:repmgr:child_node_disconnect:success=1:node=1:witness node "witness" (ID: 4) has disconnected |
| +2.41 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg1" (ID: 1) |
| +2.47 | node:pg2:repmgr:repmgrd_upstream_disconnect:success=1:node=2:unable to connect to upstream node "pg1" (ID: 1) |
| +2.64 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg1" (ID: 1) |
| +10.31 | node:pg1:repmgr:child_node_disconnect:success=1:node=1:standby node "pg2" (ID: 2) has disconnected |
| +10.32 | node:pg1:repmgr:child_node_disconnect:success=1:node=1:standby node "pg3" (ID: 3) has disconnected |
| +19.24 | node:pg1:fenced_self_read_only |
| +19.26 | node:pg1:repmgr:child_nodes_disconnect_command:success=1:node=1:"child_nodes_disconnect_command" successfully executed |
| +20.63 | node:pg2:promote_requested |
| +23.98 | node:pg2:repmgr:standby_promote:success=1:node=2:server "pg2" (ID: 2) was successfully promoted to primary |
| +24.12 | node:pg2:promoted |
| +24.20 | node:pg2:repmgr:repmgrd_failover_promote:success=1:node=2:node "pg2" (ID: 2) promoted to primary; old primary "pg1" (ID: 1) marked as failed |
| +24.31 | node:pg2:repmgr:repmgrd_reload:success=1:node=2:monitoring cluster primary "pg2" (ID: 2) |
| +24.77 | node:witness:repmgr:repmgrd_failover_follow:success=1:node=4:witness node "witness" (ID: 4) now following new primary node "pg2" (ID: 2) |
| +24.90 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg2" (ID: 2) |
| +26.65 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new witness "witness" (ID: 4) has connected |
| +28.58 | node:pg3:repmgr:standby_follow:success=1:node=3:standby attached to upstream node "pg2" (ID: 2) |
| +28.61 | node:pg3:repmgr:repmgrd_failover_follow:success=1:node=3:node "pg3" (ID: 3) now following new upstream node "pg2" (ID: 2) |
| +29.03 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg3" (ID: 3) has connected |
| +30.48 | node:pg2:wal_backfill:ok=47:failed=0 |
| +45.72 | network_restored |
| +48.76 | pg1_after_reconnect_fenced |
| +48.79 | write_probe_ok |
| +48.86 | primary_now_pg2 |
| +129.53 | workload_done |
| +130.33 | node:pg1:repmgr:repmgrd_shutdown:success=1:node=1:TERM signal received |
| +134.32 | node:pg1:repmgr:node_rejoin:success=1:node=1:node 1 is now attached to node 2 |
| +134.32 | node:pg1:rejoined_to_pg2 |
| +135.34 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg1" (ID: 1) has connected |
| +136.50 | node:pg1:repmgr:repmgrd_start:success=1:node=1:monitoring connection to upstream node "pg2" (ID: 2) |
| +137.40 | node:pg2:repmgr:repmgrd_local_disconnect:success=1:node=2:unable to connect to local node |
| +137.54 | node:pg1:repmgr:repmgrd_upstream_disconnect:success=1:node=1:unable to connect to upstream node "pg2" (ID: 2) |
| +137.66 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg2" (ID: 2) |
| +137.68 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg2" (ID: 2) |
| +138.64 | node:pg1:repmgr:standby_promote:success=1:node=1:server "pg1" (ID: 1) was successfully promoted to primary |
| +139.03 | node:pg1:repmgr:standby_switchover:success=1:node=1:node "pg1" (ID: 1) promoted to primary, node "pg2" (ID: 2) demoted to standby |
| +139.44 | node:pg2:repmgr:repmgrd_local_reconnect:success=1:node=2:reconnected to local node after 2 seconds |
| +139.45 | node:pg2:repmgr:repmgrd_standby_reconnect:success=1:node=2:node has become a standby, monitoring connection to upstream node 1 |
| +139.61 | node:pg1:repmgr:repmgrd_reload:success=1:node=1:monitoring cluster primary "pg1" (ID: 1) |
| +140.52 | node:pg1:wal_backfill:ok=45:failed=0 |
| +140.79 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg1" (ID: 1) |
| +141.53 | healed |
