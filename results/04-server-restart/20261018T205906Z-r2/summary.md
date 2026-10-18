# 04-server-restart - Primary server restarted (docker restart)

- run: `04-server-restart-20261018T205906Z-r2` (2026-10-18T20:59:06.048Z)
- workload: 20 transfers/s, logical transfers 2952, acked 2952, gave up 0

| metric | value |
| --- | --- |
| RTO from injection | 6.84 s |
| client-observed write gap | 6.8 s |
| failed attempts | 1284 |
| acked after retry | 85 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 9.8 / 19.8 / 30.1 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -21.02 | workload_start |
| +0.00 | inject |
| +0.05 | node:pg1:repmgr:repmgrd_shutdown:success=1:node=1:TERM signal received |
| +0.41 | node:pg2:repmgr:repmgrd_upstream_disconnect:success=1:node=2:unable to connect to upstream node "pg1" (ID: 1) |
| +0.60 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg1" (ID: 1) |
| +0.69 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg1" (ID: 1) |
| +1.26 | pg1_container_restarted |
| +1.51 | node:pg1:node_ready |
| +1.66 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:reconnected to upstream node after 1 seconds |
| +1.77 | node:pg3:repmgr:repmgrd_upstream_reconnect:success=1:node=3:reconnected to upstream node after 1 seconds |
| +2.36 | pg1_after_restart_primary |
| +2.46 | node:pg2:repmgr:repmgrd_upstream_reconnect:success=1:node=2:reconnected to upstream node after 2 seconds |
| +5.71 | node:pg1:repmgr:repmgrd_start:success=1:node=1:monitoring cluster primary "pg1" (ID: 1) |
| +7.46 | write_probe_ok |
| +7.50 | primary_now_pg1 |
| +7.93 | node:pg1:repmgr:child_node_new_connect:success=1:node=1:new witness "witness" (ID: 4) has connected |
| +129.66 | workload_done |
| +131.03 | healed |
