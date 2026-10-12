#!/usr/bin/env bash
set -euo pipefail
. /lab/experiments/lib.sh

RATE="${LAB_RATE:-20}"
ensure_baseline
exp_dir sync-standby-loss
primary="$(current_primary)"
for cfg in "FIRST 1 (pg2)" "ANY 1 (pg2, pg3)"; do
    label="$(echo "$cfg" | tr -cd 'A-Za-z0-9' | tr 'A-Z' 'a-z')"
    say "synchronous_standby_names = $cfg; pg2 stops 15 s into the phase"
    set_system "$primary" synchronous_standby_names "$cfg"
    run_phase "$label" 60s "$RATE"
    sleep 15
    ev "$label:stop_pg2"
    nexec pg2 lab-node pause-repmgrd
    nexec pg2 lab-node stop fast
    sleep 25
    nexec pg2 lab-node start
    nexec pg2 lab-node resume-repmgrd
    ev "$label:pg2_back"
    finish_phase "$label"
    wait_until 60 bash -c '[ "$(source /lab/runner/lib/common.sh; streaming_replicas)" = "2" ]' || true
done
reset_system "$primary" synchronous_standby_names
{
    echo "# Losing the only named synchronous standby"
    echo
    echo "$RATE transfers/s for 60 s per configuration; pg2 is stopped from second 15 to second 40."
    echo
    phases_table
} > "$RUN_DIR/result.md"
cat "$RUN_DIR/result.md"
python3 /lab/measure/report.py "$RESULTS" >/dev/null
