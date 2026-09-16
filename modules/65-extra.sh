#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

sudo -n true
install_available_packages alsa-lib ffmpeg-free yt-dlp

cliamp_target="$HOME/.local/bin/cliamp"
cliamp_state="$HOME/.config/workstation-setup/cliamp-version"
expected_state="$CLIAMP_VERSION $CLIAMP_LINUX_AMD64_SHA256"

if [[ ! -x "$cliamp_target" ]] || [[ "$(cat "$cliamp_state" 2>/dev/null)" != "$expected_state" ]]; then
  cliamp_download="$TOOLS_DIR/tmp/cliamp-${CLIAMP_VERSION}-linux-amd64"
  download_verified "$CLIAMP_LINUX_AMD64_URL" "$cliamp_download" "$CLIAMP_LINUX_AMD64_SHA256"
  mkdir -p "$(dirname "$cliamp_target")" "$(dirname "$cliamp_state")"
  install -m 0755 "$cliamp_download" "$cliamp_target"
  printf '%s\n' "$expected_state" > "$cliamp_state"
fi

[[ "$($cliamp_target --version)" == "cliamp version v$CLIAMP_VERSION" ]] ||
  die "Cliamp $CLIAMP_VERSION non disponibile dopo il setup."

"$ROOT_DIR/bin/stow-dotfiles" apply extra scripts
command_exists update-desktop-database &&
  update-desktop-database "$HOME/.local/share/applications"

python3 "$ROOT_DIR/bin/configure-sway-windows.py"
if command_exists swaymsg && swaymsg -t get_version >/dev/null 2>&1; then
  swaymsg reload >/dev/null
fi

log "Cliamp $CLIAMP_VERSION installato; avvialo con: cliamp"
