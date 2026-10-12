# Security checks 2026-10-12T12:38Z

18 passed, 0 failed. 'deny' means the action must be refused, 'allow' means it must succeed.

| check | expected | result | server answer |
| --- | --- | --- | --- |
| TLS: ledger_app over plaintext (sslmode=disable) | deny | PASS | psql: error: connection to server at "haproxy" (172.30.2.2), port 5000 failed: FATAL: pg_hba.conf rejects connection for host "172.30.2.2", user "ledger_app", d |
| TLS: verify-full rejects a host name not in the certificate (172.30.2.4) | deny | PASS | psql: error: connection to server at "172.30.2.4", port 5432 failed: server certificate for "pg1" (and 5 other names) does not match host name "172.30.2.4"  |
| TLS: ledger_app with verify-full through HAProxy | allow | PASS | ssl=true TLSv1.3 TLS_AES_256_GCM_SHA384  |
| HBA: postgres superuser over the network | deny | PASS | psql: error: connection to server at "haproxy" (172.30.2.2), port 5000 failed: FATAL: pg_hba.conf rejects connection for host "172.30.2.2", user "postgres", dat |
| HBA: replication connection without TLS | deny | PASS | psql: error: connection to server at "pg2-db" (172.30.1.5), port 5432 failed: FATAL: no pg_hba.conf entry for replication connection from host "172.30.1.7", use |
| HBA: ledger_app cannot open the repmgr database | deny | PASS | psql: error: connection to server at "haproxy" (172.30.2.2), port 5000 failed: FATAL: pg_hba.conf rejects connection for host "172.30.2.2", user "ledger_app", d |
| Privilege: ledger_app CREATE TABLE in public | deny | PASS | ERROR: permission denied for schema public LINE 1: create table lab_probe (id int) ^  |
| Privilege: ledger_app DROP TABLE accounts | deny | PASS | ERROR: must be owner of table accounts  |
| Privilege: ledger_app DELETE FROM ledger_entries | deny | PASS | ERROR: permission denied for table ledger_entries  |
| Privilege: ledger_app UPDATE ledger_entries | deny | PASS | ERROR: permission denied for table ledger_entries  |
| Privilege: ledger_app reads business tables | allow | PASS | 1203  |
| Read-only role: ledger_ro INSERT INTO users | deny | PASS | ERROR: cannot execute INSERT in a read-only transaction  |
| Read-only role: ledger_ro SELECT | allow | PASS | 74500  |
| Timeout: ledger_app statement_timeout stops a 6 s query | deny | PASS | ERROR: canceling statement due to statement timeout  |
| credcheck: weak password rejected | deny | PASS | ERROR: password length should match the configured credcheck.password_min_length (16)  |
| Auth: a role whose password is stored as md5 cannot log in (scram-sha-256 HBA) | deny | PASS | psql: error: connection to server at "haproxy" (172.30.2.2), port 5000 failed: FATAL: password authentication failed for user "ledger_ro"  |
| Auth: ledger_ro works again after resetting to a scram hash | allow | PASS | 1  |
| Auth: wrong password for ledger_app | deny | PASS | psql: error: connection to server at "haproxy" (172.30.2.2), port 5000 failed: FATAL: password authentication failed for user "ledger_app"  |
