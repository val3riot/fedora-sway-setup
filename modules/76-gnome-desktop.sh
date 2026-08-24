#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"


install_available_packages \
  gnome-shell gnome-control-center gnome-terminal \
  gnome-shell-extension-dash-to-dock

command_exists gsettings || die "gsettings non disponibile dopo l'installazione di GNOME."
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'

if command_exists gnome-extensions; then
  gnome-extensions enable dash-to-dock@micxgx.gmail.com >/dev/null 2>&1 ||
    warn "Dash to Dock installata: logout/login necessario prima di abilitarla."
fi

log "GNOME configurato"
