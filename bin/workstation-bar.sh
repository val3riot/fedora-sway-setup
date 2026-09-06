#!/usr/bin/env bash
# workstation-setup: managed bar launcher
set -Eeuo pipefail
selection="$HOME/.config/workstation-setup/bar"
config="$HOME/.config/quickshell/workstation"
case "${1:-}" in
  quickshell|waybar)
    [[ -r "$selection" ]] || { echo 'Configurare prima con --config-quickshell.' >&2; exit 1; }
    printf '%s\n' "$1" > "$selection"
    systemctl --user restart workstation-bar.service
    exit ;;
  restart) exec systemctl --user restart workstation-bar.service ;;
  run) ;;
  *) echo 'Uso: workstation-bar.sh quickshell|waybar|restart' >&2; exit 2 ;;
esac
[[ -n "${SWAYSOCK:-}" && -S "$SWAYSOCK" ]] || exit 1
exec 9>"${XDG_RUNTIME_DIR:?}/workstation-bar.lock"
flock -n 9 || exit 0
# Stop the previous session's standalone Waybar before starting either backend.
# Never remove its RPM, config, or unrelated Quickshell configurations.
pkill -u "$(id -u)" -x waybar || true
for ((attempt=0; attempt<50; attempt++)); do
  pgrep -u "$(id -u)" -x waybar >/dev/null || break
  sleep 0.1
done
if pgrep -u "$(id -u)" -x waybar >/dev/null; then
  echo 'Waybar ancora attiva: avvio barra annullato.' >&2
  exit 1
fi
backend="$(cat "$selection")"
if [[ "$backend" == quickshell ]]; then
  # A manual copy of this same config is stopped; other shells are untouched.
  quickshell kill --path "$config" >/dev/null 2>&1 || true
  if quickshell --no-duplicate --path "$config"; then
    exit 0
  fi
  echo 'Quickshell non avviabile: fallback a Waybar.' >&2
elif [[ "$backend" != waybar ]]; then
  echo 'Selettore barra non valido.' >&2
  exit 1
fi
exec waybar
