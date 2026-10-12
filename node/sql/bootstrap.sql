\set ON_ERROR_STOP on
\getenv repmgr_password REPMGR_PASSWORD
\getenv ledger_owner_password LEDGER_OWNER_PASSWORD
\getenv ledger_app_password LEDGER_APP_PASSWORD
\getenv ledger_ro_password LEDGER_RO_PASSWORD
\getenv pgmonitor_password PGMONITOR_PASSWORD
CREATE ROLE repmgr WITH LOGIN SUPERUSER REPLICATION PASSWORD :'repmgr_password';
CREATE DATABASE repmgr OWNER repmgr;
CREATE ROLE ledger_owner WITH LOGIN PASSWORD :'ledger_owner_password';
CREATE ROLE ledger_app WITH LOGIN PASSWORD :'ledger_app_password';
CREATE ROLE ledger_ro WITH LOGIN PASSWORD :'ledger_ro_password';
CREATE ROLE pgmonitor WITH LOGIN PASSWORD :'pgmonitor_password' IN ROLE pg_monitor;
ALTER ROLE ledger_app SET statement_timeout = '5s';
ALTER ROLE ledger_app SET lock_timeout = '2s';
ALTER ROLE ledger_app SET idle_in_transaction_session_timeout = '10s';
ALTER ROLE ledger_ro SET statement_timeout = '30s';
ALTER ROLE ledger_ro SET default_transaction_read_only = on;
ALTER ROLE ledger_owner SET lock_timeout = '5s';
ALTER ROLE pgmonitor SET statement_timeout = '10s';
CREATE DATABASE ledgercore OWNER ledger_owner ENCODING 'UTF8' TEMPLATE template0 LOCALE_PROVIDER icu ICU_LOCALE 'en-US' LOCALE 'C.UTF-8';
REVOKE ALL ON DATABASE ledgercore FROM PUBLIC;
GRANT CONNECT ON DATABASE ledgercore TO ledger_app, ledger_ro, pgmonitor;
\connect ledgercore
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgstattuple;
CREATE EXTENSION IF NOT EXISTS pg_buffercache;
CREATE EXTENSION IF NOT EXISTS pg_repack;
CREATE EXTENSION IF NOT EXISTS pg_cron;
GRANT USAGE ON SCHEMA cron TO ledger_owner;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO ledger_app, ledger_ro;
ALTER DEFAULT PRIVILEGES FOR ROLE ledger_owner IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ledger_app;
ALTER DEFAULT PRIVILEGES FOR ROLE ledger_owner IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO ledger_app;
ALTER DEFAULT PRIVILEGES FOR ROLE ledger_owner IN SCHEMA public GRANT SELECT ON TABLES TO ledger_ro;
ALTER DEFAULT PRIVILEGES FOR ROLE ledger_owner IN SCHEMA public GRANT SELECT ON SEQUENCES TO ledger_ro;
