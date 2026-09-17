#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

sway_conf="$ROOT_DIR/dotfiles/sway/.config/sway/config"
[[ -f "$sway_conf" ]] || sway_conf="$ROOT_DIR/templates/sway/config"
grep -Fq '# workstation-setup: managed sway config' "$sway_conf"
grep -Fq 'bindsym $mod+Return exec $term' "$sway_conf"
grep -Fq 'bindsym $mod+d exec $menu' "$sway_conf"
grep -Fq 'bindsym Print exec grim' "$sway_conf"
grep -Fq 'bindsym $mod+g exec $HOME/.local/bin/workstation-shell shortcuts' "$sway_conf"

# Quickshell native shortcuts popup and data
shortcuts_popup="$ROOT_DIR/dotfiles/quickshell/.config/quickshell/workstation/shortcuts/ShortcutsPopup.qml"
shortcuts_data="$ROOT_DIR/dotfiles/quickshell/.config/quickshell/workstation/shortcuts/ShortcutsData.js"
test -f "$shortcuts_popup"
test -f "$shortcuts_data"
grep -Fq 'Super + Invio' "$shortcuts_data"
grep -Fq 'Super + D' "$shortcuts_data"
grep -Fq 'Super + G' "$shortcuts_data"
grep -Fq 'Super + Shift + C' "$shortcuts_data"

grep -Fq "'shortcuts'" "$ROOT_DIR/dotfiles/scripts/.local/bin/workstation-shell"
grep -Fq 'name === "shortcuts"' "$ROOT_DIR/dotfiles/quickshell/.config/quickshell/workstation/desktop/DesktopTools.qml"

printf '%s\n' 'OK   desktop Sway, launcher e guida scorciatoie Quickshell'
bash -n "$ROOT_DIR/bin/configure-sway-windows.sh"
