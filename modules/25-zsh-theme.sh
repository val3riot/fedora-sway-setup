#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"


sudo -n true
install_available_packages zsh git zsh-syntax-highlighting zsh-autosuggestions

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  installer="$TOOLS_DIR/tmp/install-oh-my-zsh.sh"
  download_verified "$OH_MY_ZSH_INSTALL_URL" "$installer" "$OH_MY_ZSH_INSTALL_SHA256"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh "$installer" --unattended
fi

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

install -m 0644 "$ROOT_DIR/templates/starship.toml" "$HOME/.config/starship.toml"
install -m 0644 "$ROOT_DIR/templates/zsh-theme.zsh" "$config_dir/zsh-theme.zsh"

zshrc="$HOME/.zshrc"
touch "$zshrc"
begin='# >>> workstation-setup zsh theme >>>'
end='# <<< workstation-setup zsh theme <<<'

# Conserva il primo originale prima di una modifica gestita significativa.
[[ -e "$zshrc.workstation-setup.bak" ]] || cp -p "$zshrc" "$zshrc.workstation-setup.bak"

begin_count="$(grep -Fc "$begin" "$zshrc" || true)"
end_count="$(grep -Fc "$end" "$zshrc" || true)"
[[ "$begin_count" == "$end_count" ]] ||
  die "Blocco tema incompleto in $zshrc: ripristinalo prima di continuare (backup: $zshrc.workstation-setup.bak)."

cleaned="$(mktemp)"
awk -v begin="$begin" -v end="$end" '
  $0 == begin { managed=1; next }
  $0 == end { managed=0; next }
  !managed { print }
' "$zshrc" > "$cleaned"
while [[ -s "$cleaned" && "$(tail -n 1 "$cleaned")" == "" ]]; do
  sed -i '$d' "$cleaned"
done
{
  cat "$cleaned"
  [[ ! -s "$cleaned" ]] || printf '\n'
  printf '%s\n' "$begin"
  # HOME deve essere espansa da Zsh, non dall'installer.
  # shellcheck disable=SC2016
  printf '%s\n' '[[ -r "$HOME/.config/workstation-setup/zsh-theme.zsh" ]] && source "$HOME/.config/workstation-setup/zsh-theme.zsh"'
  printf '%s\n' "$end"
} > "$zshrc"
rm -f "$cleaned"

log "Tema Zsh/Starship configurato (backup: $zshrc.workstation-setup.bak)"
