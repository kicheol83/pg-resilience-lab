# 02-primary-kill - Primary postmaster killed (kill -9)

- run: `02-primary-kill-20261018T204247Z-r1` (2026-10-18T20:42:47.199Z)
- workload: 20 transfers/s, logical transfers 2942, acked 2942, gave up 0

| metric | value |
| --- | --- |
| RTO from injection | 8.0 s |
| client-observed write gap | 7.91 s |
| failed attempts | 1358 |
| acked after retry | 96 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 9.3 / 18.2 / 31.6 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -21.02 | workload_start |
| +0.00 | inject |
| +0.10 | node:pg1:kill_9_postmaster_13372 |
| +0.14 | node:pg1:repmgr:repmgrd_local_disconnect:success=1:node=1:unable to connect to local node |
| +0.20 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg1" (ID: 1) |
| +0.50 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg1" (ID: 1) |
| +1.09 | node:pg2:repmgr:repmgrd_upstream_disconnect:success=1:node=2:unable to connect to upstream node "pg1" (ID: 1) |
| +4.19 | node:pg2:promote_requested |
| +5.26 | node:pg2:repmgr:standby_promote:success=1:node=2:server "pg2" (ID: 2) was successfully promoted to primary |
| +5.30 | node:pg2:promoted |
| +5.40 | node:pg2:repmgr:repmgrd_failover_promote:success=1:node=2:node "pg2" (ID: 2) promoted to primary; old primary "pg1" (ID: 1) marked as failed |
| +5.41 | node:pg2:repmgr:repmgrd_reload:success=1:node=2:monitoring cluster primary "pg2" (ID: 2) |
| +5.57 | node:witness:repmgr:repmgrd_failover_follow:success=1:node=4:witness node "witness" (ID: 4) now following new primary node "pg2" (ID: 2) |
| +5.61 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg2" (ID: 2) |
| +6.88 | node:pg2:wal_backfill:ok=24:failed=0 |
| +7.51 | node:pg3:repmgr:standby_follow:success=1:node=3:standby attached to upstream node "pg2" (ID: 2) |
| +7.57 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new witness "witness" (ID: 4) has connected |
| +7.59 | node:pg3:repmgr:repmgrd_failover_follow:success=1:node=3:node "pg3" (ID: 3) now following new upstream node "pg2" (ID: 2) |
| +7.70 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg3" (ID: 3) has connected |
| +8.37 | write_probe_ok |
| +8.45 | primary_now_pg2 |
| +129.55 | workload_done |
| +133.11 | node:pg1:repmgr:node_rejoin:success=1:node=1:node 1 is now attached to node 2 |
| +133.11 | node:pg1:rejoined_to_pg2 |
| +134.62 | node:pg2:repmgr:child_node_new_connect:success=1:node=2:new standby "pg1" (ID: 1) has connected |
| +135.74 | node:pg2:repmgr:repmgrd_local_disconnect:success=1:node=2:unable to connect to local node |
| +135.99 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg2" (ID: 2) |
| +136.06 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg2" (ID: 2) |
| +137.43 | node:pg1:repmgr:standby_promote:success=1:node=1:server "pg1" (ID: 1) was successfully promoted to primary |
| +137.79 | node:pg2:repmgr:repmgrd_local_reconnect:success=1:node=2:reconnected to local node after 2 seconds |
| +137.83 | node:pg2:repmgr:repmgrd_standby_reconnect:success=1:node=2:node has become a standby, monitoring connection to upstream node 1 |
| +137.87 | node:pg1:repmgr:standby_switchover:success=1:node=1:node "pg1" (ID: 1) promoted to primary, node "pg2" (ID: 2) demoted to standby |
| +138.75 | node:pg1:repmgr:repmgrd_start:success=1:node=1:monitoring cluster primary "pg1" (ID: 1) |
| +138.89 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg1" (ID: 1) |
| +139.18 | node:pg1:wal_backfill:ok=28:failed=0 |
| +139.62 | healed |
