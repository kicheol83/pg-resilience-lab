# Acknowledged-but-lost commits under a partition

4 writers insert rows in autocommit mode while pg1 is cut off from both replicas and the witness for 20 s.
Their commits wait for a synchronous standby that cannot answer. Each phase interrupts those waits differently,
then the partition heals, pg1 is rewound to follow the new primary, and every row a writer saw as committed is
looked up on the surviving cluster.

| phase | target | statement_timeout ms | action on SyncRep waits (every 1 s) | acked rows | sync waits cancelled and reported as success | acked but lost |
| --- | --- | --- | --- | --- | --- | --- |
| timeout-only | pg1 port=5432 | 2000 | none | 548 | 0 | 0 |
| cancel-direct | pg1 port=5432 | 30000 | pg_cancel_backend | 620 | 72 | 72 |
| cancel-haproxy | haproxy port=5000 | 30000 | pg_cancel_backend | 2633 | 16 | 16 |
| terminate-haproxy | haproxy port=5000 | 30000 | pg_terminate_backend | 2460 | 0 | 0 |
