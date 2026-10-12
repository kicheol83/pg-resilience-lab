| timeout-only | pg1 port=5432 | 2000 | none | 548 | 0 | 0 |
| cancel-direct | pg1 port=5432 | 30000 | pg_cancel_backend | 620 | 72 | 72 |
| cancel-haproxy | haproxy port=5000 | 30000 | pg_cancel_backend | 2633 | 16 | 16 |
| terminate-haproxy | haproxy port=5000 | 30000 | pg_terminate_backend | 2460 | 0 | 0 |
