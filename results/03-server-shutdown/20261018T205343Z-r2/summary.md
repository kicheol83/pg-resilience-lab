# 03-server-shutdown - Primary server shut down (docker stop)

- run: `03-server-shutdown-20261018T205343Z-r2` (2026-10-18T20:53:43.430Z)
- workload: 20 transfers/s, logical transfers 2863, acked 2685, gave up 178

| metric | value |
| --- | --- |
| RTO from injection | 24.71 s |
| client-observed write gap | 24.67 s |
| failed attempts | 10239 |
| acked after retry | 170 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 9.4 / 17.8 / 267.7 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -21.01 | workload_start |
| +0.00 | inject |
| +0.05 | node:pg1:repmgr:repmgrd_shutdown:success=1:node=1:TERM signal received |
| +0.32 | node:pg2:repmgr:repmgrd_upstream_disconnect:success=1:node=2:unable to connect to upstream node "pg1" (ID: 1) |
| +0.98 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg1" (ID: 1) |
| +1.02 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg1" (ID: 1) |
| +19.50 | node:pg2:promote_requested |
| +22.68 | node:pg2:repmgr:standby_promote:success=1:node=2:server "pg2" (ID: 2) was successfully promoted to primary |
| +22.78 | node:pg2:promoted |
| +22.95 | node:pg2:repmgr:repmgrd_failover_promote:success=1:node=2:node "pg2" (ID: 2) promoted to primary; old primary "pg1" (ID: 1) marked as failed |
| +23.01 | node:pg2:repmgr:repmgrd_reload:success=1:node=2:monitoring cluster primary "pg2" (ID: 2) |
| +23.19 | node:witness:repmgr:repmgrd_failover_follow:success=1:node=4:witness node "witness" (ID: 4) now following new primary node "pg2" (ID: 2) |
| +23.23 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg2" (ID: 2) |
| +25.28 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new witness "witness" (ID: 4) has connected |
| +25.52 | node:pg3:repmgr:standby_follow:success=1:node=3:standby attached to upstream node "pg2" (ID: 2) |
| +25.55 | node:pg3:repmgr:repmgrd_failover_follow:success=1:node=3:node "pg3" (ID: 3) now following new upstream node "pg2" (ID: 2) |
| +25.83 | write_probe_ok |
| +25.91 | primary_now_pg2 |
| +26.40 | node:pg2:wal_backfill:ok=41:failed=0 |
| +27.49 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg3" (ID: 3) has connected |
| +129.61 | workload_done |
| +134.24 | node:pg1:boot_guard_detected_primary_pg2 |
| +134.53 | node:pg1:repmgr:node_rejoin:success=1:node=1:node 1 is now attached to node 2 |
| +134.54 | node:pg1:rejoined_to_pg2 |
| +134.54 | node:pg1:node_ready |
| +134.72 | node:pg1:repmgr:repmgrd_start:success=1:node=1:monitoring connection to upstream node "pg2" (ID: 2) |
| +135.22 | pg1_back_as_standby |
| +135.64 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg1" (ID: 1) has connected |
| +138.17 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg2" (ID: 2) |
| +138.67 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg2" (ID: 2) |
| +138.72 | node:pg2:repmgr:repmgrd_local_disconnect:success=1:node=2:unable to connect to local node |
| +138.83 | node:pg1:repmgr:repmgrd_upstream_disconnect:success=1:node=1:unable to connect to upstream node "pg2" (ID: 2) |
| +140.23 | node:pg1:repmgr:standby_promote:success=1:node=1:server "pg1" (ID: 1) was successfully promoted to primary |
| +140.62 | node:pg1:repmgr:standby_switchover:success=1:node=1:node "pg1" (ID: 1) promoted to primary, node "pg2" (ID: 2) demoted to standby |
| +140.83 | node:pg2:repmgr:repmgrd_local_reconnect:success=1:node=2:reconnected to local node after 2 seconds |
| +140.88 | node:pg2:repmgr:repmgrd_standby_reconnect:success=1:node=2:node has become a standby, monitoring connection to upstream node 1 |
| +140.96 | node:pg1:repmgr:repmgrd_reload:success=1:node=1:monitoring cluster primary "pg1" (ID: 1) |
| +142.11 | node:pg1:wal_backfill:ok=43:failed=0 |
| +142.34 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:reconnected to upstream node "pg1" (ID: 1) after 0 seconds, resuming monitoring |
| +142.98 | healed |
| +143.05 | node:pg1:repmgr:child_node_new_connect:success=1:node=1:new standby "pg3" (ID: 3) has connected |
