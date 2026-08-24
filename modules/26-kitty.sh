#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"


sudo -n true
install_available_packages kitty kitty-terminfo ncurses
command_exists infocmp || die "infocmp non disponibile dopo l'installazione di ncurses."
infocmp -x xterm-kitty >/dev/null 2>&1 ||
  die "Il terminfo locale xterm-kitty non è disponibile."

target="$HOME/.config/kitty/kitty.conf"
install_managed_config "$ROOT_DIR/templates/kitty.conf" "$target" '# workstation-setup: managed kitty config'
log "Kitty configurato in $target"

install -m 0755 \
  "$ROOT_DIR/bin/install-kitty-terminfo-remote" \
  "$HOME/.local/bin/install-kitty-terminfo-remote"
log "Helper terminfo remoto installato in $HOME/.local/bin/install-kitty-terminfo-remote"
