#!/usr/bin/env bash
set -euo pipefail
. /lab/runner/lib/common.sh

primary="$(current_primary)" || die "no primary"
q() {
    docker exec -i "$(cname "$primary")" lab-node psql -d ledgercore -P pager=off < "$1"
}
case "${1:-help}" in
    install) /lab/maintenance/install.sh ;;
    bloat) q /lab/maintenance/bloat-report.sql ;;
    wraparound) q /lab/maintenance/wraparound.sql ;;
    vacuum-report) q /lab/maintenance/vacuum-report.sql ;;
    repack) /lab/maintenance/repack-demo.sh ;;
    cron)
        nexec "$primary" lab-node psql -d ledgercore -P pager=off -c "select j.jobname, d.status, d.start_time, d.end_time, left(d.return_message, 60) as message from cron.job_run_details d join cron.job j using (jobid) order by d.start_time desc limit 20"
        ;;
    *) echo "usage: lab maintenance {install|bloat|wraparound|vacuum-report|repack|cron}" >&2; exit 2 ;;
esac
