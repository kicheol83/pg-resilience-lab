#!/usr/bin/env bash
set -euo pipefail
case "${1:-help}" in
    check) exec /lab/upgrade/pg-upgrade.sh check ;;
    pg-upgrade) exec /lab/upgrade/pg-upgrade.sh run ;;
    logical) exec /lab/upgrade/logical.sh ;;
    *) echo "usage: lab upgrade {check|pg-upgrade|logical}" >&2; exit 2 ;;
esac
