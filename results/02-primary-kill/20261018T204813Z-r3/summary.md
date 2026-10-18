# 02-primary-kill - Primary postmaster killed (kill -9)

- run: `02-primary-kill-20261018T204813Z-r3` (2026-10-18T20:48:13.231Z)
- workload: 20 transfers/s, logical transfers 2950, acked 2950, gave up 0

| metric | value |
| --- | --- |
| RTO from injection | 7.07 s |
| client-observed write gap | 7.02 s |
| failed attempts | 513 |
| acked after retry | 88 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 10.1 / 18.7 / 30.8 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -21.01 | workload_start |
| -20.05 | node:pg1:repmgr:child_node_new_connect:success=1:node=1:new witness "witness" (ID: 4) has connected |
| +0.00 | inject |
| +0.09 | node:pg1:kill_9_postmaster_22050 |
| +0.41 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg1" (ID: 1) |
| +0.42 | node:pg1:repmgr:repmgrd_local_disconnect:success=1:node=1:unable to connect to local node |
| +0.46 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg1" (ID: 1) |
| +0.62 | node:pg2:repmgr:repmgrd_upstream_disconnect:success=1:node=2:unable to connect to upstream node "pg1" (ID: 1) |
| +3.77 | node:pg2:promote_requested |
| +4.83 | node:pg2:repmgr:standby_promote:success=1:node=2:server "pg2" (ID: 2) was successfully promoted to primary |
| +4.85 | node:pg2:promoted |
| +4.92 | node:pg2:repmgr:repmgrd_failover_promote:success=1:node=2:node "pg2" (ID: 2) promoted to primary; old primary "pg1" (ID: 1) marked as failed |
| +4.94 | node:pg2:repmgr:repmgrd_reload:success=1:node=2:monitoring cluster primary "pg2" (ID: 2) |
| +5.51 | node:witness:repmgr:repmgrd_failover_follow:success=1:node=4:witness node "witness" (ID: 4) now following new primary node "pg2" (ID: 2) |
| +5.60 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg2" (ID: 2) |
| +6.45 | node:pg2:wal_backfill:ok=32:failed=0 |
| +6.91 | node:pg3:repmgr:standby_follow:success=1:node=3:standby attached to upstream node "pg2" (ID: 2) |
| +6.94 | node:pg3:repmgr:repmgrd_failover_follow:success=1:node=3:node "pg3" (ID: 3) now following new upstream node "pg2" (ID: 2) |
| +7.07 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new witness "witness" (ID: 4) has connected |
| +7.14 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg3" (ID: 3) has connected |
| +7.68 | write_probe_ok |
| +7.82 | primary_now_pg2 |
| +129.59 | workload_done |
| +133.08 | node:pg1:repmgr:node_rejoin:success=1:node=1:node 1 is now attached to node 2 |
| +133.09 | node:pg1:rejoined_to_pg2 |
| +133.99 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg1" (ID: 1) has connected |
| +136.04 | node:pg2:repmgr:repmgrd_local_disconnect:success=1:node=2:unable to connect to local node |
| +136.16 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg2" (ID: 2) |
| +136.43 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg2" (ID: 2) |
| +137.06 | node:pg1:repmgr:standby_promote:success=1:node=1:server "pg1" (ID: 1) was successfully promoted to primary |
| +137.48 | node:pg1:repmgr:standby_switchover:success=1:node=1:node "pg1" (ID: 1) promoted to primary, node "pg2" (ID: 2) demoted to standby |
| +138.08 | node:pg2:repmgr:repmgrd_local_reconnect:success=1:node=2:reconnected to local node after 2 seconds |
| +138.12 | node:pg2:repmgr:repmgrd_standby_reconnect:success=1:node=2:node has become a standby, monitoring connection to upstream node 1 |
| +138.25 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg1" (ID: 1) |
| +138.83 | node:pg1:wal_backfill:ok=36:failed=0 |
| +138.99 | healed |
