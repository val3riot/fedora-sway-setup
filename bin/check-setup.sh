#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
failed=0

[[ -r "$ROOT_DIR/config/sources.env" ]] || { echo "FAIL config/sources.env mancante" >&2; exit 1; }

while IFS= read -r -d '' script; do
  if bash -n "$script"; then
    printf 'OK   %s\n' "${script#"$ROOT_DIR"/}"
  else
    printf 'FAIL %s\n' "${script#"$ROOT_DIR"/}" >&2
    failed=1
  fi
done < <(find "$ROOT_DIR" -type f -name '*.sh' -print0 | sort -z)

for extra in bin/laptop-power-mode bin/stow-dotfiles; do
  if bash -n "$ROOT_DIR/$extra"; then
    printf 'OK   %s\n' "$extra"
  else
    printf 'FAIL %s\n' "$extra" >&2
    failed=1
  fi
done

exit "$failed"
