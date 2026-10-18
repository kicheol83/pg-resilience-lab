# 09-accidental-drop-pitr - Operator drops ledger_entries; recovered with PITR to the transaction before the DROP

- run: `09-accidental-drop-pitr-20261018T213738Z-r1` (2026-10-18T21:37:38.776Z)
- workload: 20 transfers/s, logical transfers 5660, acked 4894, gave up 766

| metric | value |
| --- | --- |
| RTO from injection | 73.67 s |
| client-observed write gap | 73.44 s |
| failed attempts | 37504 |
| acked after retry | 350 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 9.9 / 19.1 / 841.9 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -21.08 | node:pg1:repmgr:child_node_new_connect:success=1:node=1:new witness "witness" (ID: 4) has connected |
| -21.01 | workload_start |
| +0.00 | inject |
| +0.30 | accident_drop_table_ledger_entries |
| +2.49 | standby_pg2_table_missing=t |
| +2.65 | standby_pg3_table_missing=t |
| +10.66 | incident_detected |
| +10.96 | drop_commit_xid_72227 |
| +11.32 | node:pg1:repmgr:repmgrd_shutdown:success=1:node=1:TERM signal received |
| +11.43 | node:pg2:repmgr:repmgrd_shutdown:success=1:node=2:TERM signal received |
| +11.55 | node:pg3:repmgr:repmgrd_shutdown:success=1:node=3:TERM signal received |
| +11.63 | node:witness:repmgr:repmgrd_shutdown:success=1:node=4:TERM signal received |
| +14.85 | cluster_stopped_for_restore |
| +15.71 | pgbackrest_restore_done |
| +60.20 | pg1_recovered_and_promoted |
| +60.33 | recovery_target_settings_removed |
| +60.57 | node:pg1:repmgr:primary_register:success=1:node=1:existing primary record updated |
| +60.85 | entries_after_restore=138318 |
| +67.38 | post_restore_full_backup_done |
| +71.95 | node:pg2:repmgr:standby_register:success=1:node=2:standby registration succeeded; upstream node ID is 1 (-F/--force option was used) |
| +71.99 | pg2_reseeded_by_pgbackrest_delta |
| +74.16 | node:pg2:repmgr:repmgrd_start:success=1:node=2:monitoring connection to upstream node "pg1" (ID: 1) |
| +75.92 | node:pg3:repmgr:standby_register:success=1:node=3:standby registration succeeded; upstream node ID is 1 (-F/--force option was used) |
| +75.94 | pg3_reseeded_by_pgbackrest_delta |
| +76.41 | node:witness:repmgr:witness_register:success=1:node=4:witness registration succeeded; upstream node ID is 1 |
| +76.51 | cluster_rebuilt_on_new_timeline |
| +76.53 | write_probe_ok |
| +76.58 | primary_now_pg1 |
| +77.99 | node:pg3:repmgr:repmgrd_start:success=1:node=3:monitoring connection to upstream node "pg1" (ID: 1) |
| +78.01 | node:witness:repmgr:repmgrd_start:success=1:node=4:witness monitoring connection to primary node "pg1" (ID: 1) |
| +78.97 | node:pg1:repmgr:repmgrd_start:success=1:node=1:monitoring cluster primary "pg1" (ID: 1) |
| +81.06 | node:pg1:repmgr:child_node_new_connect:success=1:node=1:new witness "witness" (ID: 4) has connected |
| +279.58 | workload_done |
| +280.96 | healed |
