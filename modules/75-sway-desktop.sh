#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

[[ "${INCLUDE_SWAY_DESKTOP:-false}" == true ]] || exit 0

if sudo -n -v 2>/dev/null; then
  log "Sway: credenziali sudo già attive"
else
  log "Sway: richiesta credenziali sudo"
  sudo -v
fi
# Tutti i componenti del desktop provengono dai repository Fedora abilitati.
log "Sway: controllo e installazione dei pacchetti Fedora"
install_available_packages \
  sway sway-config-fedora waybar fuzzel mako swayidle swaylock \
  grim slurp wl-clipboard brightnessctl playerctl pavucontrol \
  NetworkManager-applet xdg-desktop-portal-wlr

log "Sway: verifica dei comandi installati"
for command_name in sway fuzzel waybar swaylock; do
  command_exists "$command_name" || die "$command_name non disponibile dopo l'installazione."
done

log "Sway: installazione delle configurazioni utente"
install_managed_config \
  "$ROOT_DIR/templates/sway/config" \
  "$HOME/.config/sway/config" \
  '# workstation-setup: managed sway config'
install_managed_config \
  "$ROOT_DIR/templates/sway/waybar-config.jsonc" \
  "$HOME/.config/waybar/config.jsonc" \
  '// workstation-setup: managed waybar config'
install_managed_config \
  "$ROOT_DIR/templates/sway/waybar-style.css" \
  "$HOME/.config/waybar/style.css" \
  '/* workstation-setup: managed waybar style */'
install_managed_config \
  "$ROOT_DIR/templates/sway/fuzzel.ini" \
  "$HOME/.config/fuzzel/fuzzel.ini" \
  '# workstation-setup: managed fuzzel config'

install -m 0755 "$ROOT_DIR/bin/sway-help" "$HOME/.local/bin/sway-help"
mkdir -p "$HOME/.local/share/applications"
install -m 0644 "$ROOT_DIR/templates/sway/sway-help.desktop" \
  "$HOME/.local/share/applications/workstation-sway-help.desktop"

log "Sway configurato; Super+D apre il launcher, Super+G la guida ricercabile."
