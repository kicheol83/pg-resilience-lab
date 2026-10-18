# 08-relfile-removed - Primary loses the data file of table accounts

- run: `08-relfile-removed-20261018T213455Z-r3` (2026-10-18T21:34:55.472Z)
- workload: 20 transfers/s, logical transfers 2967, acked 2967, gave up 0

| metric | value |
| --- | --- |
| RTO from injection | 6.2 s |
| client-observed write gap | 5.41 s |
| failed attempts | 72 |
| acked after retry | 72 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 8.4 / 16.4 / 29.5 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -21.01 | workload_start |
| +0.00 | inject |
| +0.68 | detected_by_synthetic_check |
| +0.89 | operator_stopped_corrupted_primary |
| +0.99 | node:pg2:repmgr:repmgrd_upstream_disconnect:success=1:node=2:unable to connect to upstream node "pg1" (ID: 1) |
| +1.56 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg1" (ID: 1) |
| +1.69 | node:pg1:repmgr:repmgrd_local_disconnect:success=1:node=1:unable to connect to local node |
| +1.72 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg1" (ID: 1) |
| +4.10 | node:pg2:promote_requested |
| +5.17 | node:pg2:repmgr:standby_promote:success=1:node=2:server "pg2" (ID: 2) was successfully promoted to primary |
| +5.19 | node:pg2:promoted |
| +5.22 | node:pg2:repmgr:repmgrd_failover_promote:success=1:node=2:node "pg2" (ID: 2) promoted to primary; old primary "pg1" (ID: 1) marked as failed |
| +5.24 | node:pg2:repmgr:repmgrd_reload:success=1:node=2:monitoring cluster primary "pg2" (ID: 2) |
| +5.60 | node:witness:repmgr:repmgrd_failover_follow:success=1:node=4:witness node "witness" (ID: 4) now following new primary node "pg2" (ID: 2) |
| +5.62 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg2" (ID: 2) |
| +5.95 | node:pg3:repmgr:standby_follow:success=1:node=3:standby attached to upstream node "pg2" (ID: 2) |
| +5.99 | node:pg3:repmgr:repmgrd_failover_follow:success=1:node=3:node "pg3" (ID: 3) now following new upstream node "pg2" (ID: 2) |
| +6.95 | write_probe_ok |
| +7.03 | primary_now_pg2 |
| +7.35 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new witness "witness" (ID: 4) has connected |
| +7.40 | node:pg2:wal_backfill:ok=39:failed=0 |
| +129.57 | workload_done |
| +131.75 | node:pg1:repmgr:standby_clone:success=1:node=1:cloned from host "pg2-db", port 5432; backup method: pg_basebackup; --force: Y |
| +132.04 | node:pg1:repmgr:standby_register:success=1:node=1:standby registration succeeded; upstream node ID is 2 (-F/--force option was used) |
| +132.05 | node:pg1:repmgr:standby_register_sync:success=1:node=1:node record synchronised after 0 seconds |
| +132.06 | node:pg1:cloned_from_pg2 |
| +132.07 | pg1_rebuilt |
| +134.02 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg1" (ID: 1) has connected |
| +135.08 | node:pg2:repmgr:repmgrd_local_disconnect:success=1:node=2:unable to connect to local node |
| +135.54 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg2" (ID: 2) |
| +135.71 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg2" (ID: 2) |
| +136.47 | node:pg1:repmgr:standby_promote:success=1:node=1:server "pg1" (ID: 1) was successfully promoted to primary |
| +136.59 | node:pg1:wal_backfill:ok=2:failed=0 |
| +136.86 | node:pg1:repmgr:standby_switchover:success=1:node=1:node "pg1" (ID: 1) promoted to primary, node "pg2" (ID: 2) demoted to standby |
| +137.16 | node:pg2:repmgr:repmgrd_local_reconnect:success=1:node=2:reconnected to local node after 2 seconds |
| +137.19 | node:pg2:repmgr:repmgrd_standby_reconnect:success=1:node=2:node has become a standby, monitoring connection to upstream node 1 |
| +138.48 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg1" (ID: 1) |
| +139.06 | healed |
