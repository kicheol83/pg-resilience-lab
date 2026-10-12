\set ON_ERROR_STOP on
SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname IN ('outbox-partitions-ahead', 'outbox-partitions-retention', 'idempotency-purge', 'cron-history-cleanup', 'analyze-hot-tables');
SELECT cron.schedule_in_database('outbox-partitions-ahead', '5 0 * * *', 'SELECT ensure_outbox_partitions(3)', 'ledgercore', 'ledger_owner');
SELECT cron.schedule_in_database('outbox-partitions-retention', '15 0 * * *', 'SELECT * FROM drop_old_outbox_partitions(3)', 'ledgercore', 'ledger_owner');
SELECT cron.schedule_in_database('idempotency-purge', '*/10 * * * *', 'SELECT purge_expired_idempotency_keys(10000)', 'ledgercore', 'ledger_owner');
SELECT cron.schedule_in_database('analyze-hot-tables', '*/30 * * * *', 'ANALYZE transactions, ledger_entries, idempotency_keys', 'ledgercore', 'ledger_owner');
SELECT cron.schedule('cron-history-cleanup', '0 1 * * *', $$DELETE FROM cron.job_run_details WHERE end_time < now() - interval '7 days'$$);
ALTER TABLE ledger_entries SET (autovacuum_vacuum_insert_scale_factor = 0.05, autovacuum_vacuum_insert_threshold = 10000, autovacuum_analyze_scale_factor = 0.02);
ALTER TABLE transactions SET (autovacuum_vacuum_insert_scale_factor = 0.05, autovacuum_analyze_scale_factor = 0.02);
ALTER TABLE idempotency_keys SET (autovacuum_vacuum_scale_factor = 0.02, autovacuum_vacuum_threshold = 1000, autovacuum_analyze_scale_factor = 0.05);
SELECT jobid, jobname, schedule, username, database FROM cron.job ORDER BY jobid;
