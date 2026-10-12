#!/usr/bin/env bash
set -euo pipefail
. /lab/runner/lib/common.sh
primary="$(current_primary)" || die "no primary"
docker exec -i "$(cname "$primary")" lab-node psql -d ledgercore -P pager=off < /lab/maintenance/install.sql
say "maintenance jobs and autovacuum settings installed on $primary (replicated to standbys)"
