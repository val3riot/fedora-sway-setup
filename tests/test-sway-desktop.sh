#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

grep -Fq '# workstation-setup: managed sway config' "$ROOT_DIR/templates/sway/config"
grep -Fq 'bindsym $mod+Return exec $term' "$ROOT_DIR/templates/sway/config"
grep -Fq 'bindsym $mod+d exec $menu' "$ROOT_DIR/templates/sway/config"
grep -Fq 'bindsym Print exec grim' "$ROOT_DIR/templates/sway/config"
grep -Fq 'bindsym $mod+g exec $HOME/.local/bin/sway-help' "$ROOT_DIR/templates/sway/config"
grep -Fq 'Super+D                 Launcher applicazioni' "$ROOT_DIR/bin/sway-help"
grep -Fq 'Super+Shift+C           Ricarica configurazione Sway' "$ROOT_DIR/bin/sway-help"
grep -Fq 'Name=Sway Help & Keybindings' "$ROOT_DIR/templates/sway/sway-help.desktop"
grep -Fq 'Exec=sway-help' "$ROOT_DIR/templates/sway/sway-help.desktop"

grep -Fq 'python3 "$ROOT_DIR/bin/configure-quickshell.py"' "$ROOT_DIR/modules/75-sway-desktop.sh"
grep -Fq 'quickshell_selected=true' "$ROOT_DIR/modules/75-sway-desktop.sh"
help_output="$(env WAYLAND_DISPLAY='' PATH=/usr/bin:/bin bash "$ROOT_DIR/bin/sway-help")"
grep -Fq 'Super+G                 Cerca questa guida dei comandi' <<<"$help_output"

printf '%s\n' 'OK   desktop Sway, launcher e guida ricercabile'
PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT_DIR/tests/test-sway-windows.py"
