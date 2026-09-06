#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"
validate_config

online=false
case "${1:-}" in
  '') ;;
  --online) online=true ;;
  *) die "Uso: $0 [--online]" ;;
esac

failed=0
if rg -n 'https?://' "$ROOT_DIR/install.sh" "$ROOT_DIR/lib" "$ROOT_DIR/modules" "$ROOT_DIR/bin" "$ROOT_DIR/templates/quickshell" \
  --glob '!**/audit-urls.sh' --glob '!**/provenance-audit.sh'; then
  printf '%s\n' 'FAIL URL runtime hardcoded fuori da config/sources.env' >&2
  failed=1
else
  printf '%s\n' 'OK   URL runtime centralizzati in config/sources.env'
fi

if rg -n --glob '!.git/**' --glob '!**/audit-urls.sh' -- \
  '--nogpgcheck|sslverify[[:space:]]*=[[:space:]]*false|curl[^#\n]*[[:space:]]-k([[:space:]]|$)|wget[^#\n]*--no-check-certificate' \
  "$ROOT_DIR"; then
  printf '%s\n' 'FAIL opzione di verifica TLS/GPG disabilitata' >&2
  failed=1
else
  printf '%s\n' 'OK   nessuna disabilitazione TLS/GPG'
fi

classify_url() {
  local name=$1 url=$2 class
  case "$url" in
    https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/*|https://raw.githubusercontent.com/nvm-sh/nvm/*|\
    https://github.com/starship/starship/*)
      class='official upstream repository' ;;
    https://get.sdkman.io*|https://repo.anaconda.com/*|https://releases.openai.com/*|\
    https://pkgs.tailscale.com/*|\
    https://claude.ai/*|https://gh.io/copilot-install*|https://download.docker.com/*|\
    https://desktop.docker.com/*|https://packages.microsoft.com/*|https://dbeaver.io/*|\
    https://api.github.com/repos/usebruno/bruno/*|https://data.services.jetbrains.com/*)
      class='official vendor/project source' ;;
    https://quickshell.org/*)
      class='official upstream documentation' ;;
    https://packages.fedoraproject.org/*)
      class='Fedora official package registry' ;;
    https://dl.flathub.org/*)
      class='community repository (vendor-supported/verified where documented)' ;;
    *)
      printf 'FAIL %-34s URL non classificato: %s\n' "$name" "$url" >&2
      failed=1
      return ;;
  esac
  printf 'OK   %-34s %s | %s\n' "$name" "$class" "$url"
  if [[ "$online" == true ]]; then
    if curl --fail --silent --show-error --location --head --max-time 30 "$url" >/dev/null; then
      printf 'OK   %-34s raggiungibile online\n' "$name"
    else
      printf 'FAIL %-34s non raggiungibile online\n' "$name" >&2
      failed=1
    fi
  fi
}

while IFS='=' read -r name _; do
  [[ "$name" == *_URL ]] || continue
  classify_url "$name" "${!name}"
done < <(sed -n -E 's/^([A-Z0-9_]+_URL)=.*/\1=/p' "$ROOT_DIR/config/sources.env")

exit "$failed"
