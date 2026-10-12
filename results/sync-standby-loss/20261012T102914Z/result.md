# Losing the only named synchronous standby

20 transfers/s for 60 s per configuration; pg2 is stopped from second 15 to second 40.

| phase | acked | throughput/s | p50 ms | p95 ms | p99 ms | max ms | attempts >= 4 s | failed attempts | gave up |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| first1pg2 | 826 | 13.8 | 10.8 | 78.3 | 1056.1 | 1529.2 | 0 | 12119 | 213 |
| any1pg2pg3 | 1201 | 20.0 | 11.0 | 23.1 | 36.4 | 92.1 | 0 | 0 | 0 |
