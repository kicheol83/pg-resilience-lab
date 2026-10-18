# 05-network-isolation - Primary fully isolated from the network for 45 s

- run: `05-network-isolation-20261018T210946Z-r3` (2026-10-18T21:09:46.408Z)
- workload: 20 transfers/s, logical transfers 2851, acked 2668, gave up 183

| metric | value |
| --- | --- |
| RTO from injection | 26.25 s |
| client-observed write gap | 26.16 s |
| failed attempts | 11054 |
| acked after retry | 183 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 9.6 / 18.5 / 166.5 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -21.01 | workload_start |
| -19.80 | node:pg1:repmgr:child_node_new_connect:success=1:node=1:new witness "witness" (ID: 4) has connected |
| +0.00 | inject |
| +0.61 | node:pg1:repmgr:child_node_disconnect:success=1:node=1:witness node "witness" (ID: 4) has disconnected |
| +2.40 | node:pg2:repmgr:repmgrd_upstream_disconnect:success=1:node=2:unable to connect to upstream node "pg1" (ID: 1) |
| +2.41 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg1" (ID: 1) |
| +3.13 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg1" (ID: 1) |
| +10.81 | node:pg1:repmgr:child_node_disconnect:success=1:node=1:standby node "pg2" (ID: 2) has disconnected |
| +10.82 | node:pg1:repmgr:child_node_disconnect:success=1:node=1:standby node "pg3" (ID: 3) has disconnected |
| +19.60 | node:pg1:fenced_self_read_only |
| +19.61 | node:pg1:repmgr:child_nodes_disconnect_command:success=1:node=1:"child_nodes_disconnect_command" successfully executed |
| +20.65 | node:pg2:promote_requested |
| +23.77 | node:pg2:repmgr:standby_promote:success=1:node=2:server "pg2" (ID: 2) was successfully promoted to primary |
| +23.82 | node:pg2:promoted |
| +23.87 | node:pg2:repmgr:repmgrd_failover_promote:success=1:node=2:node "pg2" (ID: 2) promoted to primary; old primary "pg1" (ID: 1) marked as failed |
| +23.97 | node:pg2:repmgr:repmgrd_reload:success=1:node=2:monitoring cluster primary "pg2" (ID: 2) |
| +24.28 | node:witness:repmgr:repmgrd_failover_follow:success=1:node=4:witness node "witness" (ID: 4) now following new primary node "pg2" (ID: 2) |
| +24.39 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg2" (ID: 2) |
| +26.26 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new witness "witness" (ID: 4) has connected |
| +27.01 | node:pg3:repmgr:standby_follow:success=1:node=3:standby attached to upstream node "pg2" (ID: 2) |
| +27.09 | node:pg3:repmgr:repmgrd_failover_follow:success=1:node=3:node "pg3" (ID: 3) now following new upstream node "pg2" (ID: 2) |
| +27.79 | node:pg2:wal_backfill:ok=41:failed=0 |
| +28.42 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg3" (ID: 3) has connected |
| +45.72 | network_restored |
| +48.75 | pg1_after_reconnect_fenced |
| +48.77 | write_probe_ok |
| +48.85 | primary_now_pg2 |
| +129.52 | workload_done |
| +130.27 | node:pg1:repmgr:repmgrd_shutdown:success=1:node=1:TERM signal received |
| +133.66 | node:pg1:repmgr:node_rejoin:success=1:node=1:node 1 is now attached to node 2 |
| +133.67 | node:pg1:rejoined_to_pg2 |
| +134.68 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg1" (ID: 1) has connected |
| +136.17 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg2" (ID: 2) |
| +136.73 | node:pg2:repmgr:repmgrd_local_disconnect:success=1:node=2:unable to connect to local node |
| +136.83 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg2" (ID: 2) |
| +137.87 | node:pg1:repmgr:standby_promote:success=1:node=1:server "pg1" (ID: 1) was successfully promoted to primary |
| +138.34 | node:pg1:repmgr:standby_switchover:success=1:node=1:node "pg1" (ID: 1) promoted to primary, node "pg2" (ID: 2) demoted to standby |
| +138.58 | node:pg1:repmgr:repmgrd_start:success=1:node=1:monitoring cluster primary "pg1" (ID: 1) |
| +138.78 | node:pg2:repmgr:repmgrd_local_reconnect:success=1:node=2:reconnected to local node after 2 seconds |
| +138.80 | node:pg2:repmgr:repmgrd_standby_reconnect:success=1:node=2:node has become a standby, monitoring connection to upstream node 1 |
| +139.68 | node:pg1:wal_backfill:ok=43:failed=0 |
| +140.05 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:reconnected to upstream node "pg1" (ID: 1) after 0 seconds, resuming monitoring |
| +140.66 | node:pg1:repmgr:child_node_new_connect:success=1:node=1:new standby "pg3" (ID: 3) has connected |
| +140.70 | healed |
| +140.73 | node:pg1:repmgr:child_node_new_connect:success=1:node=1:new witness "witness" (ID: 4) has connected |
