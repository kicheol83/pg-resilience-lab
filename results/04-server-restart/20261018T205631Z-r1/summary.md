# 04-server-restart - Primary server restarted (docker restart)

- run: `04-server-restart-20261018T205631Z-r1` (2026-10-18T20:56:31.437Z)
- workload: 20 transfers/s, logical transfers 2951, acked 2951, gave up 0

| metric | value |
| --- | --- |
| RTO from injection | 7.05 s |
| client-observed write gap | 6.97 s |
| failed attempts | 1301 |
| acked after retry | 85 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 10.3 / 19.3 / 34.9 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -21.01 | workload_start |
| +0.00 | inject |
| +0.08 | node:pg1:repmgr:repmgrd_shutdown:success=1:node=1:TERM signal received |
| +0.75 | node:pg2:repmgr:repmgrd_upstream_disconnect:success=1:node=2:unable to connect to upstream node "pg1" (ID: 1) |
| +0.79 | node:pg3:repmgr:repmgrd_upstream_disconnect:success=1:node=3:unable to connect to upstream node "pg1" (ID: 1) |
| +1.05 | node:witness:repmgr:repmgrd_upstream_disconnect:success=1:node=4:unable to connect to primary node "pg1" (ID: 1) |
| +1.56 | pg1_container_restarted |
| +1.80 | node:pg2:repmgr:repmgrd_upstream_reconnect:success=1:node=2:reconnected to upstream node after 1 seconds |
| +1.82 | node:pg1:node_ready |
| +1.87 | node:pg3:repmgr:repmgrd_upstream_reconnect:success=1:node=3:reconnected to upstream node after 1 seconds |
| +2.09 | node:witness:repmgr:repmgrd_upstream_reconnect:success=1:node=4:reconnected to upstream node after 1 seconds |
| +2.64 | pg1_after_restart_primary |
| +6.08 | node:pg1:repmgr:repmgrd_start:success=1:node=1:monitoring cluster primary "pg1" (ID: 1) |
| +7.43 | write_probe_ok |
| +7.53 | primary_now_pg1 |
| +8.27 | node:pg1:repmgr:child_node_new_connect:success=1:node=1:new witness "witness" (ID: 4) has connected |
| +129.59 | workload_done |
| +130.87 | healed |
