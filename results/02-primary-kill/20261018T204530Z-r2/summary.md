# 02-primary-kill - Primary postmaster killed (kill -9)

- run: `02-primary-kill-20261018T204530Z-r2` (2026-10-18T20:45:30.545Z)
- workload: 20 transfers/s, logical transfers 2971, acked 2971, gave up 0

| metric | value |
| --- | --- |
| RTO from injection | 5.48 s |
| client-observed write gap | 5.42 s |
| failed attempts | 511 |
| acked after retry | 69 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 9.4 / 17.9 / 31.6 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -21.01 | workload_start |
| +0.00 | inject |
| +0.09 | node:pg1:kill_9_postmaster_17732 |
| +0.27 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg1" (ID: 1) |
| +0.35 | node:pg2:repmgr:repmgrd_upstream_disconnect:success=1:node=2:unable to connect to upstream node "pg1" (ID: 1) |
| +0.57 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg1" (ID: 1) |
| +1.09 | node:pg1:repmgr:repmgrd_local_disconnect:success=1:node=1:unable to connect to local node |
| +3.46 | node:pg2:promote_requested |
| +4.52 | node:pg2:repmgr:standby_promote:success=1:node=2:server "pg2" (ID: 2) was successfully promoted to primary |
| +4.54 | node:pg2:promoted |
| +4.62 | node:pg2:repmgr:repmgrd_failover_promote:success=1:node=2:node "pg2" (ID: 2) promoted to primary; old primary "pg1" (ID: 1) marked as failed |
| +4.65 | node:pg2:repmgr:repmgrd_reload:success=1:node=2:monitoring cluster primary "pg2" (ID: 2) |
| +4.85 | node:pg3:repmgr:standby_follow:success=1:node=3:standby attached to upstream node "pg2" (ID: 2) |
| +4.89 | node:pg3:repmgr:repmgrd_failover_follow:success=1:node=3:node "pg3" (ID: 3) now following new upstream node "pg2" (ID: 2) |
| +5.31 | node:witness:repmgr:repmgrd_failover_follow:success=1:node=4:witness node "witness" (ID: 4) now following new primary node "pg2" (ID: 2) |
| +5.38 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg2" (ID: 2) |
| +6.09 | node:pg2:wal_backfill:ok=28:failed=0 |
| +6.14 | write_probe_ok |
| +6.19 | primary_now_pg2 |
| +6.74 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new witness "witness" (ID: 4) has connected |
| +129.62 | workload_done |
| +133.19 | node:pg1:repmgr:node_rejoin:success=1:node=1:node 1 is now attached to node 2 |
| +133.20 | node:pg1:rejoined_to_pg2 |
| +133.42 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg1" (ID: 1) has connected |
| +135.83 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg2" (ID: 2) |
| +136.32 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg2" (ID: 2) |
| +136.49 | node:pg2:repmgr:repmgrd_local_disconnect:success=1:node=2:unable to connect to local node |
| +137.16 | node:pg1:repmgr:standby_promote:success=1:node=1:server "pg1" (ID: 1) was successfully promoted to primary |
| +137.54 | node:pg2:repmgr:repmgrd_local_reconnect:success=1:node=2:reconnected to local node after 1 seconds |
| +137.58 | node:pg2:repmgr:repmgrd_standby_reconnect:success=1:node=2:node has become a standby, monitoring connection to upstream node 1 |
| +137.58 | node:pg1:repmgr:standby_switchover:success=1:node=1:node "pg1" (ID: 1) promoted to primary, node "pg2" (ID: 2) demoted to standby |
| +138.54 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:reconnected to upstream node "pg1" (ID: 1) after 0 seconds, resuming monitoring |
| +139.07 | node:pg1:wal_backfill:ok=32:failed=0 |
| +139.25 | healed |
