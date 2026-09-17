#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/lib/common.sh"

# Riapplica i pacchetti Stow per Sway e scripts
"$ROOT_DIR/bin/stow-dotfiles" apply sway scripts

# Pulisce eventuali residui legacy non più pertinenti allo scope desktop
dropin_dir="$HOME/.config/sway/config.d"
if [[ -e "$dropin_dir/65-cliamp.conf" ]]; then
  rm -f "$dropin_dir/65-cliamp.conf"
fi
if [[ -e "$HOME/.local/bin/cliamp-widget" && ! -L "$HOME/.local/bin/cliamp-widget" ]]; then
  rm -f "$HOME/.local/bin/cliamp-widget"
fi
