#!/usr/bin/env bash
set -Eeuo pipefail
[[ "${WORKSTATION_QUICKSHELL_TEST:-0}" != 1 ]] || exit 0
case "${1:-}" in
  Lock)
    if [[ -x "$HOME/.local/bin/workstation-lock" ]]; then
      exec "$HOME/.local/bin/workstation-lock"
    else
      exec swaylock -f -c 11111b
    fi ;;
  Logout) exec swaymsg exit ;;
  Suspend) exec systemctl suspend ;;
  Reboot) exec systemctl reboot ;;
  Shutdown) exec systemctl poweroff ;;
  *) exit 2 ;;
esac
