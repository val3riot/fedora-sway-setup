#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Gli agenti devono usare esclusivamente gli installer nativi ufficiali.
grep -Fq 'https://releases.openai.com/codex/releases/${CODEX_VERSION}/install.sh' "$ROOT_DIR/config/sources.env"
grep -Fq 'https://claude.ai/install.sh' "$ROOT_DIR/config/sources.env"
grep -Fq 'https://gh.io/copilot-install' "$ROOT_DIR/config/sources.env"
grep -Fq 'https://pkgs.tailscale.com/stable/fedora/tailscale.repo' "$ROOT_DIR/config/sources.env"
grep -Fq 'install_available_packages tailscale' "$ROOT_DIR/modules/12-tailscale.sh"
grep -Fq 'install_available_packages sway' "$ROOT_DIR/modules/75-sway-desktop.sh"
grep -Fq 'sway sway-config-fedora waybar fuzzel' "$ROOT_DIR/modules/75-sway-desktop.sh"
grep -Fq 'systemctl enable --now tailscaled.service' "$ROOT_DIR/modules/12-tailscale.sh"
if grep -Eq 'npm (install|i).*(-g|--global).*(codex|claude|copilot)' "$ROOT_DIR/modules/45-agents.sh"; then
  printf '%s\n' 'FAIL installazione npm agente rilevata' >&2
  exit 1
fi

# I plugin Zsh disponibili in Fedora non devono essere clonati manualmente.
grep -Fq 'zsh-syntax-highlighting zsh-autosuggestions' "$ROOT_DIR/modules/25-zsh-theme.sh"
if grep -Eq 'git clone.*(zsh-syntax-highlighting|zsh-autosuggestions)' "$ROOT_DIR/modules/25-zsh-theme.sh"; then
  printf '%s\n' 'FAIL clone manuale plugin Zsh rilevato' >&2
  exit 1
fi

# Ogni download eseguibile/archivio statico deve avere un digest configurato.
for variable in OH_MY_ZSH_INSTALL_SHA256 STARSHIP_ARCHIVE_SHA256 NVM_INSTALL_SHA256 \
  MINICONDA_INSTALLER_SHA256 CODEX_INSTALL_SHA256 CLAUDE_INSTALL_SHA256 \
  COPILOT_INSTALL_SHA256; do
  grep -Eq "^${variable}=\"?[0-9a-f]{64}\"?$" "$ROOT_DIR/config/versions.env"
done

test ! -e "$ROOT_DIR/config/defaults.env"
test ! -e "$ROOT_DIR/config/local.env.example"
grep -Fq 'setsid --wait env -u GITHUB_TOKEN -u GH_TOKEN -u OPENAI_API_KEY -u ANTHROPIC_API_KEY' \
  "$ROOT_DIR/modules/45-agents.sh"
grep -Fq 'CODEX_NON_INTERACTIVE=true' "$ROOT_DIR/modules/45-agents.sh"
grep -Fq 'agent_is_current codex "$CODEX_VERSION"' "$ROOT_DIR/modules/45-agents.sh"
grep -Fq 'agent_is_current copilot "$COPILOT_VERSION"' "$ROOT_DIR/modules/45-agents.sh"
grep -Fq -- '--release "$CODEX_VERSION"' "$ROOT_DIR/modules/45-agents.sh"
grep -Fq 'VERSION="$COPILOT_VERSION"' "$ROOT_DIR/modules/45-agents.sh"

printf '%s\n' 'OK   policy provenienza repository'
