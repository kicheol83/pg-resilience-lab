#!/usr/bin/env bash
set -euo pipefail
. /lab/runner/lib/common.sh

br() {
    nexec backup gosu postgres pgbackrest --stanza=ledger "$@"
}

case "${1:-info}" in
    full|diff|incr)
        t0="$(ts)"
        br --type="$1" backup
        say "$1 backup finished in $(awk "BEGIN{printf \"%.1f\", $(ts) - $t0}") s"
        br info | tail -n 6
        ;;
    info) br info ;;
    check) br check && say "archive and backup configuration ok" ;;
    verify)
        out="$RESULTS/restore-verify/$(date -u +%Y%m%dT%H%M%SZ)"
        mkdir -p "$out"
        line="$(nexec backup gosu postgres restore-verify "${2:-latest}")"
        echo "$line" | tee "$out/verify.json"
        {
            echo "# Restore verification $(date -u +%Y-%m-%dT%H:%MZ)"
            echo
            echo '```json'
            echo "$line" | jq .
            echo '```'
        } > "$out/result.md"
        echo "$line" | jq -e '.ok' >/dev/null
        ;;
    history) nexec backup cat /var/log/pgbackrest/verify-history.jsonl ;;
    *) echo "usage: lab backup {full|diff|incr|info|check|verify [set]|history}" >&2; exit 2 ;;
esac
