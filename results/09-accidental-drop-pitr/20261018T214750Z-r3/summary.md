# 09-accidental-drop-pitr - Operator drops ledger_entries; recovered with PITR to the transaction before the DROP

- run: `09-accidental-drop-pitr-20261018T214750Z-r3` (2026-10-18T21:47:50.463Z)
- workload: 20 transfers/s, logical transfers 5831, acked 5595, gave up 236

| metric | value |
| --- | --- |
| RTO from injection | 30.99 s |
| client-observed write gap | 30.77 s |
| failed attempts | 13165 |
| acked after retry | 201 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 9.4 / 18.9 / 43.9 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -21.01 | workload_start |
| +0.00 | inject |
| +0.32 | accident_drop_table_ledger_entries |
| +2.50 | standby_pg2_table_missing=t |
| +2.67 | standby_pg3_table_missing=t |
| +10.68 | incident_detected |
| +10.93 | drop_commit_xid_82926 |
| +11.15 | node:pg1:repmgr:repmgrd_shutdown:success=1:node=1:TERM signal received |
| +11.23 | node:pg2:repmgr:repmgrd_shutdown:success=1:node=2:TERM signal received |
| +11.41 | node:pg3:repmgr:repmgrd_shutdown:success=1:node=3:TERM signal received |
| +11.55 | node:witness:repmgr:repmgrd_shutdown:success=1:node=4:TERM signal received |
| +14.37 | cluster_stopped_for_restore |
| +16.00 | pgbackrest_restore_done |
| +20.10 | pg1_recovered_and_promoted |
| +20.25 | recovery_target_settings_removed |
| +20.47 | node:pg1:repmgr:primary_register:success=1:node=1:existing primary record updated |
| +20.81 | entries_after_restore=159440 |
| +25.75 | post_restore_full_backup_done |
| +29.65 | node:pg2:repmgr:standby_register:success=1:node=2:standby registration succeeded; upstream node ID is 1 (-F/--force option was used) |
| +29.67 | pg2_reseeded_by_pgbackrest_delta |
| +32.91 | node:pg3:repmgr:standby_register:success=1:node=3:standby registration succeeded; upstream node ID is 1 (-F/--force option was used) |
| +32.93 | pg3_reseeded_by_pgbackrest_delta |
| +33.21 | node:witness:repmgr:witness_register:success=1:node=4:witness registration succeeded; upstream node ID is 1 |
| +33.32 | cluster_rebuilt_on_new_timeline |
| +33.35 | write_probe_ok |
| +33.39 | primary_now_pg1 |
| +33.70 | node:pg3:repmgr:repmgrd_start:success=1:node=3:monitoring connection to upstream node "pg1" (ID: 1) |
| +33.81 | node:pg2:repmgr:repmgrd_start:success=1:node=2:monitoring connection to upstream node "pg1" (ID: 1) |
| +33.89 | node:witness:repmgr:repmgrd_start:success=1:node=4:witness monitoring connection to primary node "pg1" (ID: 1) |
| +34.10 | node:pg1:repmgr:repmgrd_start:success=1:node=1:monitoring cluster primary "pg1" (ID: 1) |
| +36.18 | node:pg1:repmgr:child_node_new_connect:success=1:node=1:new witness "witness" (ID: 4) has connected |
| +279.51 | workload_done |
| +281.09 | healed |
