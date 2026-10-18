# upgrade-logical - Major upgrade 17 -> 18 with logical replication and a HAProxy cutover

- run: `upgrade-logical-1792360886` (2026-10-18T22:01:26.062Z)
- workload: 20 transfers/s, logical transfers 2997, acked 2997, gave up 0

| metric | value |
| --- | --- |
| RTO from injection | 2.87 s |
| client-observed write gap | 2.43 s |
| failed attempts | 159 |
| acked after retry | 40 |
| idempotent replays | 0 |
| RPO: acked transfers missing | 0 |
| duplicate transfers | 0 |
| ledger integrity violations | 0 |
| unbalanced currencies | 0 |
| first-try latency p50 / p95 / p99 | 10.1 / 19.8 / 45.4 ms |
| data safe | yes |

## Timeline (seconds from injection)

| t | event |
| --- | --- |
| -18.91 | schema_copy_start |
| -18.58 | schema_copied |
| -18.31 | subscription_created |
| -17.72 | workload_start |
| -12.82 | initial_sync_done |
| +0.00 | inject |
| +0.00 | cutover_start |
| +1.03 | source_read_only |
| +1.47 | subscriber_caught_up |
| +2.09 | row_counts_match |
| +2.27 | sequences_synced |
| +2.55 | subscription_dropped |
| +2.57 | haproxy_points_to_pg18 |
| +3.00 | cutover_done |
| +133.11 | workload_done |
