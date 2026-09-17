#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"


sudo -n true
install_available_packages kitty kitty-terminfo ncurses zsh
command_exists infocmp || die "infocmp non disponibile dopo l'installazione di ncurses."
infocmp -x xterm-kitty >/dev/null 2>&1 ||
  die "Il terminfo locale xterm-kitty non è disponibile."

"$ROOT_DIR/bin/stow-dotfiles" apply kitty scripts
if [[ ! -e "$HOME/.config/kitty/theme.conf" ]]; then
  install -m 0644 "$ROOT_DIR/templates/themes/dark/kitty.conf" "$HOME/.config/kitty/theme.conf"
fi
log "Kitty e helper terminfo configurati tramite GNU Stow"
