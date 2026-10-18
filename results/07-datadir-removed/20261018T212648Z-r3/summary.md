# 07-datadir-removed - Primary data directory deleted while running

- run: `07-datadir-removed-20261018T212648Z-r3` (2026-10-18T21:26:48.369Z)
- workload: 20 transfers/s, logical transfers 2825, acked 2494, gave up 331

| metric | value |
| --- | --- |
| RTO from injection | 36.62 s |
| client-observed write gap | 36.01 s |
| failed attempts | 17145 |
| acked after retry | 205 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 9.0 / 18.4 / 151.2 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -21.01 | workload_start |
| +0.00 | inject |
| +28.67 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg1" (ID: 1) |
| +28.87 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg1" (ID: 1) |
| +29.29 | node:pg1:repmgr:repmgrd_local_disconnect:success=1:node=1:unable to connect to local node |
| +29.41 | node:pg2:repmgr:repmgrd_upstream_disconnect:success=1:node=2:unable to connect to upstream node "pg1" (ID: 1) |
| +32.66 | node:pg2:promote_requested |
| +33.82 | node:pg2:repmgr:standby_promote:success=1:node=2:server "pg2" (ID: 2) was successfully promoted to primary |
| +33.87 | node:pg2:promoted |
| +34.00 | node:pg2:repmgr:repmgrd_failover_promote:success=1:node=2:node "pg2" (ID: 2) promoted to primary; old primary "pg1" (ID: 1) marked as failed |
| +34.03 | node:pg2:repmgr:repmgrd_reload:success=1:node=2:monitoring cluster primary "pg2" (ID: 2) |
| +34.73 | node:witness:repmgr:repmgrd_failover_follow:success=1:node=4:witness node "witness" (ID: 4) now following new primary node "pg2" (ID: 2) |
| +34.78 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg2" (ID: 2) |
| +36.24 | node:pg3:repmgr:standby_follow:success=1:node=3:standby attached to upstream node "pg2" (ID: 2) |
| +36.24 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg3" (ID: 3) has connected |
| +36.27 | node:pg3:repmgr:repmgrd_failover_follow:success=1:node=3:node "pg3" (ID: 3) now following new upstream node "pg2" (ID: 2) |
| +36.42 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new witness "witness" (ID: 4) has connected |
| +36.86 | node:pg2:wal_backfill:ok=39:failed=0 |
| +37.45 | write_probe_ok |
| +37.54 | primary_now_pg2 |
| +129.59 | workload_done |
| +131.26 | node:pg1:repmgr:standby_clone:success=1:node=1:cloned from host "pg2-db", port 5432; backup method: pg_basebackup; --force: Y |
| +131.55 | node:pg1:repmgr:standby_register:success=1:node=1:standby registration succeeded; upstream node ID is 2 (-F/--force option was used) |
| +131.56 | node:pg1:repmgr:standby_register_sync:success=1:node=1:node record synchronised after 0 seconds |
| +131.56 | node:pg1:cloned_from_pg2 |
| +131.57 | pg1_rebuilt |
| +132.11 | node:pg1:repmgr:repmgrd_start:success=1:node=1:monitoring connection to upstream node "pg2" (ID: 2) |
| +132.57 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg1" (ID: 1) has connected |
| +134.53 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg2" (ID: 2) |
| +134.63 | node:pg2:repmgr:repmgrd_local_disconnect:success=1:node=2:unable to connect to local node |
| +135.00 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg2" (ID: 2) |
| +135.20 | node:pg1:repmgr:repmgrd_upstream_disconnect:success=1:node=1:unable to connect to upstream node "pg2" (ID: 2) |
| +135.84 | node:pg1:repmgr:standby_promote:success=1:node=1:server "pg1" (ID: 1) was successfully promoted to primary |
| +135.93 | node:pg1:wal_backfill:ok=2:failed=0 |
| +136.20 | node:pg1:repmgr:standby_switchover:success=1:node=1:node "pg1" (ID: 1) promoted to primary, node "pg2" (ID: 2) demoted to standby |
| +136.25 | node:pg1:repmgr:repmgrd_reload:success=1:node=1:monitoring cluster primary "pg1" (ID: 1) |
| +136.67 | node:pg2:repmgr:repmgrd_local_reconnect:success=1:node=2:reconnected to local node after 2 seconds |
| +136.69 | node:pg2:repmgr:repmgrd_standby_reconnect:success=1:node=2:node has become a standby, monitoring connection to upstream node 1 |
| +136.85 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg1" (ID: 1) |
| +137.49 | healed |
