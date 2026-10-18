# 08-relfile-removed - Primary loses the data file of table accounts

- run: `08-relfile-removed-20261018T212931Z-r1` (2026-10-18T21:29:31.669Z)
- workload: 20 transfers/s, logical transfers 2961, acked 2961, gave up 0

| metric | value |
| --- | --- |
| RTO from injection | 6.71 s |
| client-observed write gap | 6.01 s |
| failed attempts | 754 |
| acked after retry | 77 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 8.6 / 18.4 / 47.2 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -21.01 | workload_start |
| +0.00 | inject |
| +0.64 | detected_by_synthetic_check |
| +0.85 | operator_stopped_corrupted_primary |
| +1.14 | node:pg2:repmgr:repmgrd_upstream_disconnect:success=1:node=2:unable to connect to upstream node "pg1" (ID: 1) |
| +1.26 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg1" (ID: 1) |
| +1.46 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg1" (ID: 1) |
| +1.73 | node:pg1:repmgr:repmgrd_local_disconnect:success=1:node=1:unable to connect to local node |
| +4.24 | node:pg2:promote_requested |
| +5.33 | node:pg2:repmgr:standby_promote:success=1:node=2:server "pg2" (ID: 2) was successfully promoted to primary |
| +5.37 | node:pg2:promoted |
| +5.43 | node:pg2:repmgr:repmgrd_failover_promote:success=1:node=2:node "pg2" (ID: 2) promoted to primary; old primary "pg1" (ID: 1) marked as failed |
| +5.45 | node:pg2:repmgr:repmgrd_reload:success=1:node=2:monitoring cluster primary "pg2" (ID: 2) |
| +5.83 | node:pg3:repmgr:standby_follow:success=1:node=3:standby attached to upstream node "pg2" (ID: 2) |
| +5.86 | node:pg3:repmgr:repmgrd_failover_follow:success=1:node=3:node "pg3" (ID: 3) now following new upstream node "pg2" (ID: 2) |
| +6.32 | node:witness:repmgr:repmgrd_failover_follow:success=1:node=4:witness node "witness" (ID: 4) now following new primary node "pg2" (ID: 2) |
| +6.35 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg2" (ID: 2) |
| +7.27 | write_probe_ok |
| +7.38 | primary_now_pg2 |
| +7.76 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new witness "witness" (ID: 4) has connected |
| +8.26 | node:pg2:wal_backfill:ok=39:failed=0 |
| +129.65 | workload_done |
| +131.52 | node:pg1:repmgr:standby_clone:success=1:node=1:cloned from host "pg2-db", port 5432; backup method: pg_basebackup; --force: Y |
| +131.80 | node:pg1:repmgr:standby_register:success=1:node=1:standby registration succeeded; upstream node ID is 2 (-F/--force option was used) |
| +131.80 | node:pg1:repmgr:standby_register_sync:success=1:node=1:node record synchronised after 0 seconds |
| +131.81 | node:pg1:cloned_from_pg2 |
| +131.82 | pg1_rebuilt |
| +132.22 | node:pg1:repmgr:repmgrd_start:success=1:node=1:monitoring connection to upstream node "pg2" (ID: 2) |
| +132.25 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg1" (ID: 1) has connected |
| +135.34 | node:pg2:repmgr:repmgrd_local_disconnect:success=1:node=2:unable to connect to local node |
| +135.34 | node:pg1:repmgr:repmgrd_upstream_disconnect:success=1:node=1:unable to connect to upstream node "pg2" (ID: 2) |
| +135.38 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg2" (ID: 2) |
| +135.60 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg2" (ID: 2) |
| +136.48 | node:pg1:repmgr:standby_promote:success=1:node=1:server "pg1" (ID: 1) was successfully promoted to primary |
| +136.57 | node:pg1:wal_backfill:ok=2:failed=0 |
| +136.84 | node:pg1:repmgr:standby_switchover:success=1:node=1:node "pg1" (ID: 1) promoted to primary, node "pg2" (ID: 2) demoted to standby |
| +137.37 | node:pg2:repmgr:repmgrd_local_reconnect:success=1:node=2:reconnected to local node after 2 seconds |
| +137.40 | node:pg1:repmgr:repmgrd_reload:success=1:node=1:monitoring cluster primary "pg1" (ID: 1) |
| +137.44 | node:pg2:repmgr:repmgrd_standby_reconnect:success=1:node=2:node has become a standby, monitoring connection to upstream node 1 |
| +137.67 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg1" (ID: 1) |
| +138.05 | healed |
