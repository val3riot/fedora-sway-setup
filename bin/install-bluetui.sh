#!/usr/bin/env bash
# Official upstream release: Fedora 44 fedora/updates do not package BlueTUI.
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/config/sources.env"
case "$(uname -m)" in
  x86_64) url=$BLUETUI_X86_64_URL; digest=$BLUETUI_X86_64_SHA256 ;;
  aarch64) url=$BLUETUI_AARCH64_URL; digest=$BLUETUI_AARCH64_SHA256 ;;
  *) die 'BlueTUI: architettura senza release ufficiale verificata.' ;;
esac
target="$HOME/.local/bin/bluetui"
receipt="$HOME/.local/share/workstation-setup/bluetui.sha256"
[[ ! -L "$target" && ! -L "$receipt" ]] || die 'BlueTUI: symlink personale da preservare.'
if [[ -e "$target" ]]; then
  current=$(sha256sum "$target"); current=${current%% *}
  if [[ "$current" != "$digest" ]]; then
    [[ -f "$receipt" && "$(cat "$receipt")" == "$current" ]] || die 'BlueTUI personale/modificato: preservato.'
  fi
else
  current=''
fi
if [[ "${1:-}" == --check ]]; then
  [[ "$current" == "$digest" && -x "$target" ]] || die 'BlueTUI release ufficiale assente o checksum non conforme; eseguire bin/install-bluetui.sh.'
  printf 'OK   BlueTUI %s: official upstream release, SHA-256 verificato\n' "$BLUETUI_VERSION"
  exit 0
fi
[[ $# == 0 ]] || die 'Uso: install-bluetui.sh [--check]'
if [[ "$current" != "$digest" ]]; then
  mkdir -p "$(dirname "$target")"
  work=$(mktemp -d "${target}.install.XXXXXX")
  trap 'rm -rf "$work"' EXIT
  download_verified "$url" "$work/bluetui" "$digest"
  chmod 0755 "$work/bluetui"
  mv "$work/bluetui" "$target"
fi
chmod 0755 "$target"
mkdir -p "$(dirname "$receipt")"
printf '%s\n' "$digest" > "$receipt"
printf 'OK   BlueTUI %s installato da release ufficiale verificata\n' "$BLUETUI_VERSION"
