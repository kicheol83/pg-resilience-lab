# synchronous_commit vs transfer latency

30 transfers/s for 60s per mode, 1 primary + 2 standbys, synchronous_standby_names = 'ANY 1 (pg1, pg2, pg3)'.
Latency is the first-attempt API latency of POST /v1/transfers (whole request, not only COMMIT).

| phase | acked | throughput/s | p50 ms | p95 ms | p99 ms | max ms | attempts >= 4 s | failed attempts | gave up |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| off | 1801 | 30.0 | 8.8 | 17.8 | 28.3 | 89.5 | 0 | 0 | 0 |
| local | 1801 | 30.0 | 9.4 | 18.5 | 28.3 | 60.9 | 0 | 0 | 0 |
| remote_write | 1801 | 30.0 | 9.6 | 20.8 | 35.0 | 88.1 | 0 | 0 | 0 |
| on | 1801 | 30.0 | 10.2 | 20.8 | 31.7 | 146.0 | 0 | 0 | 0 |
| remote_apply | 1801 | 30.0 | 10.0 | 20.3 | 30.9 | 120.9 | 0 | 0 | 0 |
