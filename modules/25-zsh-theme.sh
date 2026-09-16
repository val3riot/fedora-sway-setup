#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"


sudo -n true
install_available_packages zsh git zsh-syntax-highlighting zsh-autosuggestions

config_dir="$HOME/.config/workstation-setup"
mkdir -p "$config_dir" "$HOME/.config"

starship_path="$(command -v starship 2>/dev/null || true)"
starship_state="$config_dir/starship-version"
if [[ -z "$starship_path" || "$starship_path" == "$HOME/.local/bin/starship" ]] &&
   { [[ ! -x "$HOME/.local/bin/starship" ]] || [[ "$(cat "$starship_state" 2>/dev/null)" != "$STARSHIP_VERSION $STARSHIP_ARCHIVE_SHA256" ]]; }; then
  archive="$TOOLS_DIR/tmp/starship-${STARSHIP_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
  extract_dir="$(mktemp -d)"
  download_verified "$STARSHIP_ARCHIVE_URL" "$archive" "$STARSHIP_ARCHIVE_SHA256"
  tar -xzf "$archive" -C "$extract_dir" starship
  mkdir -p "$HOME/.local/bin"
  install -m 0755 "$extract_dir/starship" "$HOME/.local/bin/starship"
  printf '%s %s\n' "$STARSHIP_VERSION" "$STARSHIP_ARCHIVE_SHA256" > "$starship_state"
  rm -r -- "$extract_dir"
fi

"$ROOT_DIR/bin/stow-dotfiles" apply shell

log "Tema Zsh/Starship configurato tramite GNU Stow"
