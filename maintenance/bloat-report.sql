SELECT c.relname AS table_name,
       pg_size_pretty(pg_table_size(c.oid)) AS table_size,
       round(s.approx_free_percent::numeric, 1) AS free_pct,
       round(s.dead_tuple_percent::numeric, 1) AS dead_pct,
       st.n_live_tup,
       st.n_dead_tup,
       st.last_autovacuum,
       st.autovacuum_count
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = 'public'
JOIN pg_stat_user_tables st ON st.relid = c.oid
CROSS JOIN LATERAL pgstattuple_approx(c.oid) s
WHERE c.relkind = 'r'
ORDER BY pg_table_size(c.oid) DESC
LIMIT 10;
