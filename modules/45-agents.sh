#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"


AGENTS_ROOT="$TOOLS_DIR/Agents"
CODEX_HOME="$HOME/.codex"
CLAUDE_CONFIG_DIR="$AGENTS_ROOT/claude"
COPILOT_HOME="$AGENTS_ROOT/copilot"
export AGENTS_ROOT CODEX_HOME CLAUDE_CONFIG_DIR COPILOT_HOME
mkdir -p "$AGENTS_ROOT" "$CODEX_HOME" "$CLAUDE_CONFIG_DIR" "$COPILOT_HOME" "$HOME/.local/bin"
chmod 700 "$AGENTS_ROOT" "$CODEX_HOME" "$CLAUDE_CONFIG_DIR" "$COPILOT_HOME"
command_exists setsid || die "setsid non disponibile: installa util-linux."

agent_version() {
  local executable=$1 executable_path="$HOME/.local/bin/$1"
  if [[ ! -x "$executable_path" ]]; then
    executable_path="$(command -v "$executable" 2>/dev/null || true)"
  fi
  [[ -n "$executable_path" ]] || return 1
  "$executable_path" --version 2>/dev/null |
    grep -Eo '[0-9]+\.[0-9]+\.[0-9]+([-+][[:alnum:].-]+)?' |
    head -n 1
}

agent_is_current() {
  local executable=$1 expected_version=$2 installed_version
  installed_version="$(agent_version "$executable" || true)"
  [[ "$installed_version" == "$expected_version" ]]
}

# Mantiene il percorso organizzativo storico senza spostare ~/.codex mentre
# Codex può essere in esecuzione e senza separare autenticazione e configurazione.
codex_alias="$AGENTS_ROOT/codex"
if [[ ! -e "$codex_alias" && ! -L "$codex_alias" ]]; then
  ln -s "$CODEX_HOME" "$codex_alias"
elif [[ -L "$codex_alias" && "$(readlink -f "$codex_alias")" != "$(readlink -f "$CODEX_HOME")" ]]; then
  die "$codex_alias è un link verso una destinazione inattesa; non verrà sovrascritto."
elif [[ -d "$codex_alias" && ! -L "$codex_alias" && "$codex_alias" != "$CODEX_HOME" ]]; then
  warn "$codex_alias è una directory reale preesistente: conservata senza modifiche."
fi

remove_legacy_npm_agent() {
  local package=$1
  export NVM_DIR="$TOOLS_DIR/nvm"
  [[ -s "$NVM_DIR/nvm.sh" ]] || return 0
  # shellcheck disable=SC1090
  source "$NVM_DIR/nvm.sh"
  command_exists npm || return 0
  if npm list --global --depth=0 --json 2>/dev/null |
    jq -e --arg package "$package" '.dependencies[$package] != null' >/dev/null; then
    log "Rimozione precedente installazione npm: $package"
    npm uninstall --global "$package"
  fi
}

install_vendor_agent() {
  local label=$1 url=$2 installer=$3 expected_sha256=$4
  shift 4
  log "Installazione $label dalla fonte ufficiale"
  download_verified "$url" "$installer" "$expected_sha256"
  # I bootstrap non necessitano delle credenziali applicative. Non ereditarle:
  # limita l'impatto anche in caso di compromissione della fonte vendor.
  setsid --wait env -u GITHUB_TOKEN -u GH_TOKEN -u OPENAI_API_KEY -u ANTHROPIC_API_KEY \
    CODEX_NON_INTERACTIVE=true bash "$installer" "$@" </dev/null
}

if agent_is_current codex "$CODEX_VERSION"; then
  log "Codex $CODEX_VERSION già installato: nessuna reinstallazione"
else
  remove_legacy_npm_agent '@openai/codex'
  install_vendor_agent \
    'OpenAI Codex (standalone)' \
    "$CODEX_INSTALL_URL" \
    "$TOOLS_DIR/tmp/install-codex.sh" \
    "$CODEX_INSTALL_SHA256" \
    --release "$CODEX_VERSION"
fi

if agent_is_current claude "$CLAUDE_VERSION"; then
  log "Claude Code $CLAUDE_VERSION già installato: nessuna reinstallazione"
else
  remove_legacy_npm_agent '@anthropic-ai/claude-code'
  install_vendor_agent \
    'Anthropic Claude Code (native)' \
    "$CLAUDE_INSTALL_URL" \
    "$TOOLS_DIR/tmp/install-claude-code.sh" \
    "$CLAUDE_INSTALL_SHA256" \
    "$CLAUDE_VERSION"
fi

if agent_is_current copilot "$COPILOT_VERSION"; then
  log "Copilot CLI $COPILOT_VERSION già installato: nessuna reinstallazione"
else
  remove_legacy_npm_agent '@github/copilot'
  log 'Installazione GitHub Copilot CLI dallo script ufficiale'
  copilot_installer="$TOOLS_DIR/tmp/install-copilot-cli.sh"
  download_verified "$COPILOT_INSTALL_URL" "$copilot_installer" "$COPILOT_INSTALL_SHA256"
  setsid --wait env -u GITHUB_TOKEN -u GH_TOKEN -u OPENAI_API_KEY -u ANTHROPIC_API_KEY \
    VERSION="$COPILOT_VERSION" PREFIX="$HOME/.local" \
    bash "$copilot_installer" </dev/null
fi

agent_is_current codex "$CODEX_VERSION" || die "Codex $CODEX_VERSION non disponibile dopo il setup."
agent_is_current claude "$CLAUDE_VERSION" || die "Claude Code $CLAUDE_VERSION non disponibile dopo il setup."
agent_is_current copilot "$COPILOT_VERSION" || die "Copilot CLI $COPILOT_VERSION non disponibile dopo il setup."

printf '%s\n' \
  "AGENTS_ROOT=$AGENTS_ROOT" \
  "CODEX_HOME=$CODEX_HOME" \
  "CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR" \
  "COPILOT_HOME=$COPILOT_HOME"
