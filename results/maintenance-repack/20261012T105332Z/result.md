# VACUUM FULL vs pg_repack under write load

idempotency_keys is filled with 600000 rows and about half of them are purged by purge_expired_idempotency_keys(),
which leaves the table mostly empty space that plain VACUUM cannot give back. Each method then rebuilds the
table while 20 transfers/s keep writing to the same table through the API.

| method | size before | free space before | size after | duration s |
| --- | --- | --- | --- | --- |
| vacuum-full | 426M | 49.9 % | 213M | 4.4 |
| pg-repack | 623M | 35.4 % | 406M | 13.7 |

Transfer latency during each phase (the phase includes 20 s before the rebuild starts):

| phase | acked | throughput/s | p50 ms | p95 ms | p99 ms | max ms | attempts >= 4 s | failed attempts | gave up |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| vacuum-full | 1779 | 19.8 | 11.2 | 30.0 | 2079.2 | 3075.8 | 0 | 23 | 0 |
| pg-repack | 1801 | 20.0 | 11.4 | 355.4 | 835.5 | 1779.9 | 0 | 0 | 0 |
