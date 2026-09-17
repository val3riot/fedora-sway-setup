#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

sway_conf="$ROOT_DIR/dotfiles/sway/.config/sway/config"
[[ -f "$sway_conf" ]] || sway_conf="$ROOT_DIR/templates/sway/config"
grep -Fq '# workstation-setup: managed sway config' "$sway_conf"
grep -Fq 'bindsym $mod+Return exec $term' "$sway_conf"
grep -Fq 'bindsym $mod+d exec $menu' "$sway_conf"
grep -Fq 'bindsym Print exec grim' "$sway_conf"
grep -Fq 'bindsym $mod+g exec $HOME/.local/bin/sway-help' "$sway_conf"
grep -Fq 'Super+D                 Launcher applicazioni' "$ROOT_DIR/bin/sway-help"
grep -Fq 'Super+Shift+C           Ricarica configurazione Sway' "$ROOT_DIR/bin/sway-help"
help_desktop="$ROOT_DIR/dotfiles/sway/.local/share/applications/workstation-sway-help.desktop"
[[ -f "$help_desktop" ]] || help_desktop="$ROOT_DIR/templates/sway/sway-help.desktop"
grep -Fq 'Name=Sway Help & Keybindings' "$help_desktop"
grep -Fq 'Exec=sway-help' "$help_desktop"

grep -Fq 'python3 "$ROOT_DIR/bin/configure-quickshell.py"' "$ROOT_DIR/modules/75-sway-desktop.sh"
grep -Fq 'quickshell_selected=true' "$ROOT_DIR/modules/75-sway-desktop.sh"
help_output="$(env WAYLAND_DISPLAY='' PATH=/usr/bin:/bin bash "$ROOT_DIR/bin/sway-help")"
grep -Fq 'Super+G                 Cerca questa guida dei comandi' <<<"$help_output"

printf '%s\n' 'OK   desktop Sway, launcher e guida ricercabile'
bash -n "$ROOT_DIR/bin/configure-sway-windows.sh"
