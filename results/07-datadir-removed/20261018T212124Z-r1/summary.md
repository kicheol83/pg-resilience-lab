# 07-datadir-removed - Primary data directory deleted while running

- run: `07-datadir-removed-20261018T212124Z-r1` (2026-10-18T21:21:24.407Z)
- workload: 20 transfers/s, logical transfers 2824, acked 2532, gave up 292

| metric | value |
| --- | --- |
| RTO from injection | 35.28 s |
| client-observed write gap | 34.15 s |
| failed attempts | 15765 |
| acked after retry | 209 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 9.4 / 17.8 / 270.2 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -21.01 | workload_start |
| +0.00 | inject |
| +0.35 | write_probe_ok |
| +0.44 | primary_now_none |
| +28.67 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg1" (ID: 1) |
| +28.69 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg1" (ID: 1) |
| +28.71 | node:pg1:repmgr:repmgrd_local_disconnect:success=1:node=1:unable to connect to local node |
| +28.76 | node:pg2:repmgr:repmgrd_upstream_disconnect:success=1:node=2:unable to connect to upstream node "pg1" (ID: 1) |
| +31.94 | node:pg2:promote_requested |
| +33.04 | node:pg2:repmgr:standby_promote:success=1:node=2:server "pg2" (ID: 2) was successfully promoted to primary |
| +33.10 | node:pg2:promoted |
| +33.25 | node:pg2:repmgr:repmgrd_failover_promote:success=1:node=2:node "pg2" (ID: 2) promoted to primary; old primary "pg1" (ID: 1) marked as failed |
| +33.28 | node:pg2:repmgr:repmgrd_reload:success=1:node=2:monitoring cluster primary "pg2" (ID: 2) |
| +33.76 | node:witness:repmgr:repmgrd_failover_follow:success=1:node=4:witness node "witness" (ID: 4) now following new primary node "pg2" (ID: 2) |
| +33.81 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg2" (ID: 2) |
| +35.21 | node:pg3:repmgr:standby_follow:success=1:node=3:standby attached to upstream node "pg2" (ID: 2) |
| +35.27 | node:pg3:repmgr:repmgrd_failover_follow:success=1:node=3:node "pg3" (ID: 3) now following new upstream node "pg2" (ID: 2) |
| +35.73 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg3" (ID: 3) has connected |
| +35.89 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new witness "witness" (ID: 4) has connected |
| +37.48 | node:pg2:wal_backfill:ok=38:failed=0 |
| +129.65 | workload_done |
| +131.06 | node:pg1:repmgr:standby_clone:success=1:node=1:cloned from host "pg2-db", port 5432; backup method: pg_basebackup; --force: Y |
| +131.33 | node:pg1:repmgr:standby_register:success=1:node=1:standby registration succeeded; upstream node ID is 2 (-F/--force option was used) |
| +131.34 | node:pg1:repmgr:standby_register_sync:success=1:node=1:node record synchronised after 0 seconds |
| +131.35 | node:pg1:cloned_from_pg2 |
| +131.35 | pg1_rebuilt |
| +132.01 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg1" (ID: 1) has connected |
| +132.21 | node:pg1:repmgr:repmgrd_start:success=1:node=1:monitoring connection to upstream node "pg2" (ID: 2) |
| +134.68 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg2" (ID: 2) |
| +134.98 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg2" (ID: 2) |
| +135.10 | node:pg2:repmgr:repmgrd_local_disconnect:success=1:node=2:unable to connect to local node |
| +135.30 | node:pg1:repmgr:repmgrd_upstream_disconnect:success=1:node=1:unable to connect to upstream node "pg2" (ID: 2) |
| +135.99 | node:pg1:repmgr:standby_promote:success=1:node=1:server "pg1" (ID: 1) was successfully promoted to primary |
| +136.12 | node:pg1:wal_backfill:ok=2:failed=0 |
| +136.35 | node:pg1:repmgr:repmgrd_reload:success=1:node=1:monitoring cluster primary "pg1" (ID: 1) |
| +136.39 | node:pg1:repmgr:standby_switchover:success=1:node=1:node "pg1" (ID: 1) promoted to primary, node "pg2" (ID: 2) demoted to standby |
| +137.01 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg1" (ID: 1) |
| +137.13 | node:pg2:repmgr:repmgrd_local_reconnect:success=1:node=2:reconnected to local node after 2 seconds |
| +137.16 | node:pg2:repmgr:repmgrd_standby_reconnect:success=1:node=2:node has become a standby, monitoring connection to upstream node 1 |
| +137.65 | healed |
