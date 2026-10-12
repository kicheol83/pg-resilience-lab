SELECT relname,
       n_live_tup,
       n_dead_tup,
       n_ins_since_vacuum,
       last_autovacuum,
       last_autoanalyze,
       autovacuum_count,
       autoanalyze_count,
       (SELECT reloptions FROM pg_class WHERE oid = relid) AS reloptions
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_live_tup DESC;
SELECT pid, relid::regclass, phase, heap_blks_scanned, heap_blks_total FROM pg_stat_progress_vacuum;
