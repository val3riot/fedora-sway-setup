#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

grep -Fq '# workstation-setup: managed sway config' "$ROOT_DIR/templates/sway/config"
grep -Fq 'bindsym --no-warn $mod+Return exec $term' "$ROOT_DIR/templates/sway/config"
grep -Fq 'bindsym --no-warn $mod+d exec $menu' "$ROOT_DIR/templates/sway/config"
grep -Fq 'bindsym --no-warn Print exec grim' "$ROOT_DIR/templates/sway/config"
grep -Fq 'bindsym $mod+g exec $HOME/.local/bin/sway-help' "$ROOT_DIR/templates/sway/config"
grep -Fq 'Super+D                 Launcher applicazioni' "$ROOT_DIR/bin/sway-help"
grep -Fq 'Super+Shift+C           Ricarica configurazione Sway' "$ROOT_DIR/bin/sway-help"
grep -Fq 'Name=Sway Help & Keybindings' "$ROOT_DIR/templates/sway/sway-help.desktop"
grep -Fq 'Exec=sway-help' "$ROOT_DIR/templates/sway/sway-help.desktop"
grep -Fq 'Sway: richiesta credenziali sudo' "$ROOT_DIR/modules/75-sway-desktop.sh"
grep -Fq 'Sway: credenziali sudo già attive' "$ROOT_DIR/modules/75-sway-desktop.sh"
grep -Fq 'Sway: controllo e installazione dei pacchetti Fedora' "$ROOT_DIR/modules/75-sway-desktop.sh"
grep -Fq 'Sway: installazione delle configurazioni utente' "$ROOT_DIR/modules/75-sway-desktop.sh"

help_output="$(env WAYLAND_DISPLAY='' PATH=/usr/bin:/bin bash "$ROOT_DIR/bin/sway-help")"
grep -Fq 'Super+G                 Cerca questa guida dei comandi' <<<"$help_output"

printf '%s\n' 'OK   desktop Sway, launcher e guida ricercabile'
