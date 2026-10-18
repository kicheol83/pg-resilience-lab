# 04-server-restart - Primary server restarted (docker restart)

- run: `04-server-restart-20261018T210140Z-r3` (2026-10-18T21:01:40.680Z)
- workload: 20 transfers/s, logical transfers 2956, acked 2956, gave up 0

| metric | value |
| --- | --- |
| RTO from injection | 6.58 s |
| client-observed write gap | 6.51 s |
| failed attempts | 1183 |
| acked after retry | 82 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 10.2 / 19.9 / 35.7 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -21.02 | workload_start |
| +0.00 | inject |
| +0.05 | node:pg1:repmgr:repmgrd_shutdown:success=1:node=1:TERM signal received |
| +0.59 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg1" (ID: 1) |
| +1.36 | pg1_container_restarted |
| +1.61 | node:pg1:node_ready |
| +1.65 | node:pg3:repmgr:repmgrd_upstream_reconnect:success=1:node=3:reconnected to upstream node after 1 seconds |
| +2.46 | pg1_after_restart_primary |
| +5.85 | node:pg1:repmgr:repmgrd_start:success=1:node=1:monitoring cluster primary "pg1" (ID: 1) |
| +7.01 | write_probe_ok |
| +7.07 | primary_now_pg1 |
| +8.07 | node:pg1:repmgr:child_node_new_connect:success=1:node=1:new witness "witness" (ID: 4) has connected |
| +8.61 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:witness monitoring connection to primary node "pg1" (ID: 1) |
| +129.57 | workload_done |
| +131.01 | healed |
