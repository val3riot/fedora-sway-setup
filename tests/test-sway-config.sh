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
grep -Fq 'set $term kitty' "$ROOT_DIR/templates/sway/config"
grep -Fq 'bash "$ROOT_DIR/modules/26-kitty.sh" </dev/null' "$ROOT_DIR/modules/75-sway-desktop.sh"
grep -Fq 'install_available_packages kitty kitty-terminfo ncurses zsh' "$ROOT_DIR/modules/26-kitty.sh"
grep -Fq 'lxqt-policykit' "$ROOT_DIR/modules/75-sway-desktop.sh"
grep -Fq '/usr/libexec/lxqt-policykit-agent' "$ROOT_DIR/templates/sway/config"
! grep -Fq 'polkit-gnome' "$ROOT_DIR/modules/75-sway-desktop.sh"
! grep -Fq 'polkit-gnome' "$ROOT_DIR/templates/sway/config"
grep -Fq "timeout 3600 '\$lock'" "$ROOT_DIR/templates/sway/config"
grep -Fq 'xkb_layout it' "$ROOT_DIR/templates/sway/config"
grep -Fq 'HandleLidSwitch=suspend' "$ROOT_DIR/templates/logind-lid.conf"
grep -Fq 'HandleLidSwitchExternalPower=suspend' "$ROOT_DIR/templates/logind-lid.conf"
grep -Fq 'HandleLidSwitchDocked=suspend' "$ROOT_DIR/templates/logind-lid.conf"
grep -Fq '/etc/systemd/logind.conf.d/90-workstation-setup-lid.conf' "$ROOT_DIR/modules/75-sway-desktop.sh"
grep -Fq 'xdg-desktop-portal/sway-portals.conf' "$ROOT_DIR/modules/75-sway-desktop.sh"
grep -Fq 'gnome-shell-extension-dash-to-dock' "$ROOT_DIR/modules/76-gnome-desktop.sh"
test -x "$ROOT_DIR/bin/waybar-cpu-temperature"

printf '%s\n' 'OK   configurazione Sway e sudo non interattivo'
