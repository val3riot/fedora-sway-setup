#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Endpoint ufficiali per artefatti desktop
grep -Fq 'https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/${OH_MY_ZSH_COMMIT}/tools/install.sh' "$ROOT_DIR/config/sources.env"
grep -Fq 'https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-x86_64-unknown-linux-gnu.tar.gz' "$ROOT_DIR/config/sources.env"
grep -Fq 'https://github.com/pythops/bluetui/releases/download/v${BLUETUI_VERSION}/bluetui-x86_64-linux-musl' "$ROOT_DIR/config/sources.env"

# Pacchetti desktop installati da repository ufficiali Fedora
grep -Fq 'install_available_packages sway' "$ROOT_DIR/modules/75-sway-desktop.sh"
grep -Fq 'sway sway-config-fedora swayidle swaylock' "$ROOT_DIR/modules/75-sway-desktop.sh"
! grep -Eq 'waybar|fuzzel|mako' "$ROOT_DIR/modules/75-sway-desktop.sh"

# I plugin Zsh disponibili in Fedora non devono essere clonati manualmente.
grep -Fq 'zsh-syntax-highlighting zsh-autosuggestions' "$ROOT_DIR/modules/25-zsh-theme.sh"
if grep -Eq 'git clone.*(zsh-syntax-highlighting|zsh-autosuggestions)' "$ROOT_DIR/modules/25-zsh-theme.sh"; then
  printf '%s\n' 'FAIL clone manuale plugin Zsh rilevato' >&2
  exit 1
fi

# Ogni download eseguibile/archivio statico deve avere un digest configurato in versions.env.
for variable in OH_MY_ZSH_INSTALL_SHA256 STARSHIP_ARCHIVE_SHA256 BLUETUI_X86_64_SHA256; do
  grep -Eq "^${variable}=\"?[0-9a-f]{64}\"?$" "$ROOT_DIR/config/versions.env"
done

# Pinned commit Oh My Zsh
grep -Eq '^OH_MY_ZSH_COMMIT="?[0-9a-f]{40}"?$' "$ROOT_DIR/config/versions.env"

test ! -e "$ROOT_DIR/config/defaults.env"
test ! -e "$ROOT_DIR/config/local.env.example"

printf '%s\n' 'OK   policy provenienza repository desktop'
