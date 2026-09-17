#!/usr/bin/env bash
# workstation-setup: wallpaper setter wrapper
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/lib/common.sh"

exec python3 "$ROOT_DIR/bin/workstation-wallpaper" "$@"
