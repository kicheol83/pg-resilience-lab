#!/usr/bin/env bash
set -euo pipefail
. /lab/experiments/lib.sh

RATE="${LAB_RATE:-30}"
DURATION="${LAB_DURATION:-60s}"
ensure_baseline
exp_dir sync-commit
primary="$(current_primary)"
for mode in off local remote_write on remote_apply; do
    say "synchronous_commit = $mode"
    set_system "$primary" synchronous_commit "$mode"
    run_phase "$mode" "$DURATION" "$RATE"
    finish_phase "$mode"
done
reset_system "$primary" synchronous_commit
{
    echo "# synchronous_commit vs transfer latency"
    echo
    echo "$RATE transfers/s for $DURATION per mode, 1 primary + 2 standbys, synchronous_standby_names = 'ANY 1 (pg1, pg2, pg3)'."
    echo "Latency is the first-attempt API latency of POST /v1/transfers (whole request, not only COMMIT)."
    echo
    phases_table
} > "$RUN_DIR/result.md"
cat "$RUN_DIR/result.md"
python3 /lab/measure/report.py "$RESULTS" >/dev/null
