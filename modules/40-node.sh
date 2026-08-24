#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

export NVM_DIR="$TOOLS_DIR/nvm"
if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
  mkdir -p "$NVM_DIR"
  installer="$TOOLS_DIR/tmp/install-nvm.sh"
  download_verified "$NVM_INSTALL_URL" "$installer" "$NVM_INSTALL_SHA256"
  PROFILE=/dev/null bash "$installer"
fi
# shellcheck disable=SC1090
source "$NVM_DIR/nvm.sh"
nvm install "$NVM_NODE_VERSION"
if [[ "$NVM_NODE_VERSION" == "--lts" ]]; then
  nvm alias default 'lts/*'
else
  nvm alias default "$NVM_NODE_VERSION"
fi
command -v corepack >/dev/null 2>&1 && corepack enable || true
