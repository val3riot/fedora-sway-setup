#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"


sudo -n true
install_available_packages tmux

target="$HOME/.tmux.conf"
install_managed_config "$ROOT_DIR/templates/tmux.conf" "$target" '# workstation-setup: managed tmux config'
log "tmux configurato in $target (reload: prefix + r)"
