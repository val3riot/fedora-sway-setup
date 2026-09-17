#!/usr/bin/env bash
# workstation-setup: managed bar launcher (Quickshell)
set -Eeuo pipefail

config="$HOME/.config/quickshell/workstation"

case "${1:-run}" in
  restart) exec systemctl --user restart workstation-bar.service ;;
  run|quickshell) ;;
  *) echo 'Uso: workstation-bar.sh [run|restart]' >&2; exit 2 ;;
esac

[[ -n "${SWAYSOCK:-}" && -S "$SWAYSOCK" ]] || exit 1
exec 9>"${XDG_RUNTIME_DIR:?}/workstation-bar.lock"
flock -n 9 || exit 0

export WORKSTATION_NOTIFICATIONS=quickshell
quickshell kill --path "$config" >/dev/null 2>&1 || true
exec quickshell --no-duplicate --path "$config"
