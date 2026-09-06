#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT_DIR/tests/test-quickshell.py"
# All power actions must be inert even when invoked directly in test mode.
for action in Lock Logout Suspend Reboot Shutdown; do
  WORKSTATION_QUICKSHELL_TEST=1 bash "$ROOT_DIR/templates/quickshell/services/power.sh" "$action"
done
# No feature flag: module must return without requiring sudo or writing files.
env CONFIG_QUICKSHELL=false ROOT_DIR="$ROOT_DIR" bash "$ROOT_DIR/modules/76-quickshell.sh"
grep -Fq -- '--config-quickshell' <("$ROOT_DIR/install.sh" --help)
printf '%s\n' 'OK   Quickshell statistics, migration, idempotence, opt-in and safe power actions'
