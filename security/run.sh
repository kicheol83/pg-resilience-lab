#!/usr/bin/env bash
set -uo pipefail
. /lab/runner/lib/common.sh

out="$RESULTS/security/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$out"
primary="$(current_primary)" || die "no primary"
pass=0
fail=0
rows=()

record() {
    local name="$1" expect="$2" rc="$3" detail="$4" verdict
    if { [ "$expect" = "deny" ] && [ "$rc" -ne 0 ]; } || { [ "$expect" = "allow" ] && [ "$rc" -eq 0 ]; }; then
        verdict="PASS"
        pass=$((pass + 1))
    else
        verdict="FAIL"
        fail=$((fail + 1))
    fi
    detail="$(echo "$detail" | tr '\n' ' ' | sed -E 's/\s+/ /g; s/\|/\\|/g' | cut -c1-160)"
    rows+=("| $name | $expect | $verdict | $detail |")
    printf '%-4s %-62s %s\n' "$verdict" "$name" "$detail"
}

try() {
    local name="$1" expect="$2"
    shift 2
    local output rc
    output="$("$@" 2>&1)"
    rc=$?
    record "$name" "$expect" "$rc" "$output"
}

pg1_ip="$(getent hosts pg1 | awk '{print $1}' | head -n 1)"

try "TLS: ledger_app over plaintext (sslmode=disable)" deny \
    env PGPASSWORD="$LEDGER_APP_PASSWORD" psql "host=haproxy port=5000 dbname=ledgercore user=ledger_app sslmode=disable connect_timeout=3" -Atc "select 1"
try "TLS: verify-full rejects a host name not in the certificate ($pg1_ip)" deny \
    env PGPASSWORD="$LEDGER_APP_PASSWORD" psql "host=$pg1_ip port=5432 dbname=ledgercore user=ledger_app sslmode=verify-full sslrootcert=$CA connect_timeout=3" -Atc "select 1"
try "TLS: ledger_app with verify-full through HAProxy" allow \
    env PGPASSWORD="$LEDGER_APP_PASSWORD" psql "$(conn ledger_app)" -Atc "select 'ssl=' || ssl || ' ' || version || ' ' || cipher from pg_stat_ssl where pid = pg_backend_pid()"
try "HBA: postgres superuser over the network" deny \
    env PGPASSWORD=whatever psql "host=haproxy port=5000 dbname=postgres user=postgres sslmode=require connect_timeout=3" -Atc "select 1"
try "HBA: replication connection without TLS" deny \
    env PGPASSWORD="$REPMGR_PASSWORD" psql "host=pg2-db port=5432 dbname=replication replication=true user=repmgr sslmode=disable connect_timeout=3" -c "IDENTIFY_SYSTEM"
try "HBA: ledger_app cannot open the repmgr database" deny \
    env PGPASSWORD="$LEDGER_APP_PASSWORD" psql "host=haproxy port=5000 dbname=repmgr user=ledger_app sslmode=verify-full sslrootcert=$CA connect_timeout=3" -Atc "select 1"
try "Privilege: ledger_app CREATE TABLE in public" deny sql_as ledger_app -c "create table lab_probe (id int)"
try "Privilege: ledger_app DROP TABLE accounts" deny sql_as ledger_app -c "drop table accounts"
try "Privilege: ledger_app DELETE FROM ledger_entries" deny sql_as ledger_app -c "delete from ledger_entries where id < 0"
try "Privilege: ledger_app UPDATE ledger_entries" deny sql_as ledger_app -c "update ledger_entries set amount = amount where id < 0"
try "Privilege: ledger_app reads business tables" allow sql_as ledger_app -c "select count(*) from accounts"
try "Read-only role: ledger_ro INSERT INTO users" deny sql_as ledger_ro -c "insert into users (email) values ('ro-probe@lab.test')"
try "Read-only role: ledger_ro SELECT" allow sql_as ledger_ro -c "select count(*) from transactions"
try "Timeout: ledger_app statement_timeout stops a 6 s query" deny sql_as ledger_app -c "select pg_sleep(6)"
try "credcheck: weak password rejected" deny \
    nexec "$primary" lab-node psql -d postgres -c "create role lab_weak_probe login password 'password123'"
printf '%s\n' "set password_encryption = 'md5';" "alter role ledger_ro password 'Legacy-Md5-Passw0rd-99!';" \
    | docker exec -i "$(cname "$primary")" lab-node psql -d postgres >/dev/null 2>&1
try "Auth: a role whose password is stored as md5 cannot log in (scram-sha-256 HBA)" deny \
    env PGPASSWORD='Legacy-Md5-Passw0rd-99!' psql "$(conn ledger_ro)" -Atc "select 1"
printf '%s\n' '\getenv pw LEDGER_RO_PASSWORD' "alter role ledger_ro password :'pw';" \
    | docker exec -i "$(cname "$primary")" lab-node psql -d postgres >/dev/null
try "Auth: ledger_ro works again after resetting to a scram hash" allow sql_as ledger_ro -c "select 1"
nexec "$primary" lab-node psql -d postgres -c "drop role if exists lab_weak_probe" >/dev/null 2>&1
try "Auth: wrong password for ledger_app" deny \
    env PGPASSWORD='Wrong-Passw0rd-123!' psql "$(conn ledger_app)" -Atc "select 1"

{
    echo "# Security checks $(date -u +%Y-%m-%dT%H:%MZ)"
    echo
    echo "$pass passed, $fail failed. 'deny' means the action must be refused, 'allow' means it must succeed."
    echo
    echo "| check | expected | result | server answer |"
    echo "| --- | --- | --- | --- |"
    printf '%s\n' "${rows[@]}"
} > "$out/result.md"
python3 /lab/measure/report.py "$RESULTS" >/dev/null
say "security: $pass passed, $fail failed -> results/security/$(basename "$out")/result.md"
[ "$fail" -eq 0 ]
