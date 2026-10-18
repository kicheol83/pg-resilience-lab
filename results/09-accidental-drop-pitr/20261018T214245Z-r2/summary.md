# 09-accidental-drop-pitr - Operator drops ledger_entries; recovered with PITR to the transaction before the DROP

- run: `09-accidental-drop-pitr-20261018T214245Z-r2` (2026-10-18T21:42:45.063Z)
- workload: 20 transfers/s, logical transfers 5821, acked 5586, gave up 235

| metric | value |
| --- | --- |
| RTO from injection | 32.03 s |
| client-observed write gap | 31.72 s |
| failed attempts | 13404 |
| acked after retry | 212 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 9.7 / 18.5 / 38.1 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -21.01 | workload_start |
| +0.00 | inject |
| +0.42 | accident_drop_table_ledger_entries |
| +2.55 | standby_pg2_table_missing=t |
| +2.76 | standby_pg3_table_missing=t |
| +10.77 | incident_detected |
| +10.98 | drop_commit_xid_77233 |
| +11.21 | node:pg1:repmgr:repmgrd_shutdown:success=1:node=1:TERM signal received |
| +11.33 | node:pg2:repmgr:repmgrd_shutdown:success=1:node=2:TERM signal received |
| +11.42 | node:pg3:repmgr:repmgrd_shutdown:success=1:node=3:TERM signal received |
| +11.56 | node:witness:repmgr:repmgrd_shutdown:success=1:node=4:TERM signal received |
| +14.60 | cluster_stopped_for_restore |
| +16.36 | pgbackrest_restore_done |
| +20.96 | pg1_recovered_and_promoted |
| +21.12 | recovery_target_settings_removed |
| +21.28 | node:pg1:repmgr:primary_register:success=1:node=1:existing primary record updated |
| +21.66 | entries_after_restore=148188 |
| +26.56 | post_restore_full_backup_done |
| +30.62 | node:pg2:repmgr:standby_register:success=1:node=2:standby registration succeeded; upstream node ID is 1 (-F/--force option was used) |
| +30.72 | pg2_reseeded_by_pgbackrest_delta |
| +33.78 | node:pg2:repmgr:repmgrd_start:success=1:node=2:monitoring connection to upstream node "pg1" (ID: 1) |
| +34.53 | node:pg3:repmgr:standby_register:success=1:node=3:standby registration succeeded; upstream node ID is 1 (-F/--force option was used) |
| +34.54 | pg3_reseeded_by_pgbackrest_delta |
| +34.79 | node:witness:repmgr:witness_register:success=1:node=4:witness registration succeeded; upstream node ID is 1 |
| +34.93 | cluster_rebuilt_on_new_timeline |
| +34.95 | write_probe_ok |
| +34.99 | primary_now_pg1 |
| +37.70 | node:pg3:repmgr:repmgrd_start:success=1:node=3:monitoring connection to upstream node "pg1" (ID: 1) |
| +37.80 | node:witness:repmgr:repmgrd_start:success=1:node=4:witness monitoring connection to primary node "pg1" (ID: 1) |
| +38.17 | node:pg1:repmgr:repmgrd_start:success=1:node=1:monitoring cluster primary "pg1" (ID: 1) |
| +40.27 | node:pg1:repmgr:child_node_new_connect:success=1:node=1:new witness "witness" (ID: 4) has connected |
| +279.59 | workload_done |
| +281.03 | healed |
