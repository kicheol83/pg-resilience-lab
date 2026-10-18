# upgrade-pg-upgrade - Major upgrade 17 -> 18 with pg_upgrade --link (whole repmgr cluster)

- run: `upgrade-1792361136` (2026-10-18T22:05:36.731Z)
- workload: 20 transfers/s, logical transfers 2856, acked 2730, gave up 126

| metric | value |
| --- | --- |
| RTO from injection | 22.48 s |
| client-observed write gap | 22.6 s |
| failed attempts | 8534 |
| acked after retry | 174 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 10.4 / 19.8 / 365.1 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -25.06 | pre_upgrade_full_backup_start |
| -22.62 | pre_upgrade_full_backup_done |
| -21.89 | workload_start |
| -0.77 | node:pg1:repmgr:repmgrd_shutdown:success=1:node=1:TERM signal received |
| -0.65 | node:pg2:repmgr:repmgrd_shutdown:success=1:node=2:TERM signal received |
| -0.53 | node:pg3:repmgr:repmgrd_shutdown:success=1:node=3:TERM signal received |
| -0.43 | node:witness:repmgr:repmgrd_shutdown:success=1:node=4:TERM signal received |
| -0.00 | standbys_stopped |
| +0.00 | inject |
| +0.85 | old_primary_stopped |
| +17.14 | pg_upgrade_done |
| +17.62 | new_primary_started_pg18 |
| +17.84 | pgbackrest_stanza_upgraded |
| +18.15 | node:pg1:repmgr:primary_register:success=1:node=1:existing primary record updated |
| +20.20 | node:pg2:repmgr:standby_clone:success=1:node=2:cloned from host "pg1-db", port 5432; backup method: pg_basebackup; --force: Y |
| +20.67 | node:pg2:repmgr:standby_register:success=1:node=2:standby registration succeeded; upstream node ID is 1 (-F/--force option was used) |
| +20.68 | node:pg2:repmgr:standby_register_sync:success=1:node=2:node record synchronised after 0 seconds |
| +20.69 | node:pg2:cloned_from_pg1 |
| +20.71 | pg2_recloned_on_pg18 |
| +21.67 | node:pg2:repmgr:repmgrd_start:success=1:node=2:monitoring connection to upstream node "pg1" (ID: 1) |
| +22.67 | node:pg3:repmgr:standby_clone:success=1:node=3:cloned from host "pg1-db", port 5432; backup method: pg_basebackup; --force: Y |
| +23.10 | node:pg3:repmgr:standby_register:success=1:node=3:standby registration succeeded; upstream node ID is 1 (-F/--force option was used) |
| +23.14 | node:pg3:repmgr:standby_register_sync:success=1:node=3:node record synchronised after 0 seconds |
| +23.15 | node:pg3:cloned_from_pg1 |
| +23.17 | pg3_recloned_on_pg18 |
| +25.51 | node:pg1:repmgr:repmgrd_start:success=1:node=1:monitoring cluster primary "pg1" (ID: 1) |
| +25.74 | node:pg3:repmgr:repmgrd_start:success=1:node=3:monitoring connection to upstream node "pg1" (ID: 1) |
| +25.79 | node:witness:repmgr:repmgrd_start:success=1:node=4:witness monitoring connection to primary node "pg1" (ID: 1) |
| +27.66 | node:pg1:repmgr:child_node_new_connect:success=1:node=1:new witness "witness" (ID: 4) has connected |
| +128.91 | workload_done |
| +131.56 | post_upgrade_full_backup_done |
| +132.37 | server_version_18.0 |
