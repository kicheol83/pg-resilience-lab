# 03-server-shutdown - Primary server shut down (docker stop)

- run: `03-server-shutdown-20261018T203140Z-r1` (2026-10-18T20:31:40.417Z)
- workload: 20 transfers/s, logical transfers 2852, acked 2631, gave up 221

| metric | value |
| --- | --- |
| RTO from injection | 27.93 s |
| client-observed write gap | 27.88 s |
| failed attempts | 12310 |
| acked after retry | 183 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 10.1 / 20.0 / 158.4 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -21.01 | workload_start |
| +0.00 | inject |
| +0.06 | node:pg1:repmgr:repmgrd_shutdown:success=1:node=1:TERM signal received |
| +0.13 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg1" (ID: 1) |
| +2.88 | node:pg2:repmgr:repmgrd_upstream_disconnect:success=1:node=2:unable to connect to upstream node "pg1" (ID: 1) |
| +2.92 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg1" (ID: 1) |
| +21.05 | node:pg2:promote_requested |
| +24.16 | node:pg2:repmgr:standby_promote:success=1:node=2:server "pg2" (ID: 2) was successfully promoted to primary |
| +24.21 | node:pg2:promoted |
| +24.37 | node:pg2:repmgr:repmgrd_failover_promote:success=1:node=2:node "pg2" (ID: 2) promoted to primary; old primary "pg1" (ID: 1) marked as failed |
| +24.53 | node:pg3:repmgr:repmgrd_shutdown:success=1:node=3:TERM signal received |
| +24.58 | node:pg2:repmgr:repmgrd_reload:success=1:node=2:monitoring cluster primary "pg2" (ID: 2) |
| +24.82 | node:pg2:wal_backfill:ok=6:failed=0 |
| +25.21 | node:witness:repmgr:repmgrd_failover_follow:success=1:node=4:witness node "witness" (ID: 4) now following new primary node "pg2" (ID: 2) |
| +25.30 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg2" (ID: 2) |
| +26.77 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new witness "witness" (ID: 4) has connected |
| +28.99 | node:pg3:repmgr:standby_follow:success=1:node=3:standby attached to upstream node "pg2" (ID: 2) |
| +29.08 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg3" (ID: 3) has connected |
| +30.47 | write_probe_ok |
| +30.56 | primary_now_pg2 |
| +32.04 | node:pg3:watchdog_follow_pg2 |
| +34.72 | node:pg3:repmgr:repmgrd_start:success=1:node=3:monitoring connection to upstream node "pg2" (ID: 2) |
| +129.77 | workload_done |
| +133.40 | node:pg1:boot_guard_detected_primary_pg2 |
| +134.66 | node:pg1:repmgr:node_rejoin:success=1:node=1:node 1 is now attached to node 2 |
| +134.67 | node:pg1:rejoined_to_pg2 |
| +134.67 | node:pg1:node_ready |
| +134.80 | node:pg1:repmgr:repmgrd_start:success=1:node=1:monitoring connection to upstream node "pg2" (ID: 2) |
| +135.31 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg1" (ID: 1) has connected |
| +135.39 | pg1_back_as_standby |
| +138.43 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg2" (ID: 2) |
| +138.44 | node:pg2:repmgr:repmgrd_local_disconnect:success=1:node=2:unable to connect to local node |
| +138.92 | node:pg1:repmgr:repmgrd_upstream_disconnect:success=1:node=1:unable to connect to upstream node "pg2" (ID: 2) |
| +139.21 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg2" (ID: 2) |
| +140.22 | node:pg1:repmgr:standby_promote:success=1:node=1:server "pg1" (ID: 1) was successfully promoted to primary |
| +140.60 | node:pg1:repmgr:standby_switchover:success=1:node=1:node "pg1" (ID: 1) promoted to primary, node "pg2" (ID: 2) demoted to standby |
| +140.72 | node:pg1:wal_backfill:ok=11:failed=0 |
| +140.98 | node:pg1:repmgr:repmgrd_reload:success=1:node=1:monitoring cluster primary "pg1" (ID: 1) |
| +141.50 | node:pg2:repmgr:repmgrd_local_reconnect:success=1:node=2:reconnected to local node after 3 seconds |
| +141.53 | node:pg2:repmgr:repmgrd_standby_reconnect:success=1:node=2:node has become a standby, monitoring connection to upstream node 1 |
| +142.30 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:reconnected to upstream node "pg1" (ID: 1) after 0 seconds, resuming monitoring |
| +142.90 | healed |
