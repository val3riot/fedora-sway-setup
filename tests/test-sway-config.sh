#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

grep -Fq -- '--sway' "$ROOT_DIR/install.sh"
grep -Fq -- '--gnome' "$ROOT_DIR/install.sh"
grep -Fq 'DESKTOP_ENV=sway' "$ROOT_DIR/install.sh"
grep -Fq 'DESKTOP_ENV=gnome' "$ROOT_DIR/install.sh"
grep -Fq 'start_sudo_keepalive' "$ROOT_DIR/install.sh"
grep -Fq 'sudo -n true' "$ROOT_DIR/lib/common.sh"
grep -Fq 'bash "$module" </dev/null' "$ROOT_DIR/install.sh"
grep -Fq 'dnf install -y --skip-unavailable' "$ROOT_DIR/lib/common.sh"
grep -Fq 'sdkman_auto_answer=true' "$ROOT_DIR/modules/30-sdkman.sh"
grep -Fq 'workstation-setup.jpg' "$ROOT_DIR/templates/sway/config"
grep -Fq 'wpctl set-volume' "$ROOT_DIR/templates/sway/config"
grep -Fq 'xdg-desktop-portal/sway-portals.conf' "$ROOT_DIR/modules/75-sway-desktop.sh"
grep -Fq 'gnome-shell-extension-dash-to-dock' "$ROOT_DIR/modules/76-gnome-desktop.sh"
test -x "$ROOT_DIR/bin/waybar-cpu-temperature"

printf '%s\n' 'OK   configurazione Sway e sudo non interattivo'
