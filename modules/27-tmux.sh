#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"


sudo -n true
install_available_packages tmux

"$ROOT_DIR/bin/stow-dotfiles" apply tmux
log "tmux configurato tramite GNU Stow (reload: prefix + r)"
