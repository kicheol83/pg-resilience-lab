# 06-disk-full - Primary WAL volume runs out of space

- run: `06-disk-full-20261018T211248Z-r1` (2026-10-18T21:12:48.092Z)
- workload: 20 transfers/s, logical transfers 2944, acked 2944, gave up 0

| metric | value |
| --- | --- |
| RTO from injection | 9.03 s |
| client-observed write gap | 7.65 s |
| failed attempts | 625 |
| acked after retry | 95 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 9.1 / 18.2 / 36.6 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -21.01 | workload_start |
| -20.61 | node:pg1:repmgr:repmgrd_start:success=1:node=1:monitoring cluster primary "pg1" (ID: 1) |
| -18.53 | node:pg1:repmgr:child_node_new_connect:success=1:node=1:new witness "witness" (ID: 4) has connected |
| +0.00 | inject |
| +0.20 | ballast_written_headroom_24MB |
| +1.45 | bulk_write_attempted |
| +1.57 | pg1_role_down |
| +1.78 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg1" (ID: 1) |
| +1.79 | node:pg2:repmgr:repmgrd_upstream_disconnect:success=1:node=2:unable to connect to upstream node "pg1" (ID: 1) |
| +1.91 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg1" (ID: 1) |
| +1.97 | node:pg1:repmgr:repmgrd_local_disconnect:success=1:node=1:unable to connect to local node |
| +4.91 | node:pg2:promote_requested |
| +5.90 | node:witness:repmgr:repmgrd_failover_follow:success=1:node=4:witness node "witness" (ID: 4) now following new primary node "pg2" (ID: 2) |
| +5.99 | node:pg2:repmgr:standby_promote:success=1:node=2:server "pg2" (ID: 2) was successfully promoted to primary |
| +6.02 | node:pg2:promoted |
| +6.07 | node:pg2:repmgr:repmgrd_failover_promote:success=1:node=2:node "pg2" (ID: 2) promoted to primary; old primary "pg1" (ID: 1) marked as failed |
| +6.10 | node:pg2:repmgr:repmgrd_reload:success=1:node=2:monitoring cluster primary "pg2" (ID: 2) |
| +7.06 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:reconnected to upstream node "pg2" (ID: 2) after 2 seconds, resuming monitoring |
| +7.99 | node:pg2:wal_backfill:ok=43:failed=0 |
| +8.34 | node:pg3:repmgr:standby_follow:success=1:node=3:standby attached to upstream node "pg2" (ID: 2) |
| +8.36 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg3" (ID: 3) has connected |
| +8.40 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new witness "witness" (ID: 4) has connected |
| +8.41 | node:pg3:repmgr:repmgrd_failover_follow:success=1:node=3:node "pg3" (ID: 3) now following new upstream node "pg2" (ID: 2) |
| +9.73 | write_probe_ok |
| +9.83 | primary_now_pg2 |
| +129.54 | workload_done |
| +131.51 | node:pg1:repmgr:standby_clone:success=1:node=1:cloned from host "pg2-db", port 5432; backup method: pg_basebackup; --force: Y |
| +131.80 | node:pg1:repmgr:standby_register:success=1:node=1:standby registration succeeded; upstream node ID is 2 (-F/--force option was used) |
| +131.81 | node:pg1:repmgr:standby_register_sync:success=1:node=1:node record synchronised after 0 seconds |
| +131.82 | node:pg1:cloned_from_pg2 |
| +131.83 | pg1_rebuilt_with_wal_back_in_pgdata |
| +132.28 | node:pg1:repmgr:repmgrd_start:success=1:node=1:monitoring connection to upstream node "pg2" (ID: 2) |
| +133.18 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg1" (ID: 1) has connected |
| +134.73 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg2" (ID: 2) |
| +135.24 | node:pg2:repmgr:repmgrd_local_disconnect:success=1:node=2:unable to connect to local node |
| +135.31 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg2" (ID: 2) |
| +135.36 | node:pg1:repmgr:repmgrd_upstream_disconnect:success=1:node=1:unable to connect to upstream node "pg2" (ID: 2) |
| +136.26 | node:pg1:repmgr:standby_promote:success=1:node=1:server "pg1" (ID: 1) was successfully promoted to primary |
| +136.36 | node:pg1:wal_backfill:ok=2:failed=0 |
| +136.63 | node:pg1:repmgr:standby_switchover:success=1:node=1:node "pg1" (ID: 1) promoted to primary, node "pg2" (ID: 2) demoted to standby |
| +137.29 | node:pg2:repmgr:repmgrd_local_reconnect:success=1:node=2:reconnected to local node after 2 seconds |
| +137.31 | node:pg2:repmgr:repmgrd_standby_reconnect:success=1:node=2:node has become a standby, monitoring connection to upstream node 1 |
| +137.42 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg1" (ID: 1) |
| +137.46 | node:pg1:repmgr:repmgrd_reload:success=1:node=1:monitoring cluster primary "pg1" (ID: 1) |
| +138.09 | healed |
