#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
config="$ROOT_DIR/templates/kitty.conf"
copy_all='map ctrl+shift+a launch --stdin-source=@screen_scrollback --type=clipboard'

[[ "$(grep -Fxc "$copy_all" "$config")" == 1 ]]
[[ "$(grep -Eic '^[[:space:]]*map[[:space:]]+ctrl\+shift\+a([[:space:]]|$)' "$config")" == 1 ]]
if grep -Eiq '^[[:space:]]*map[[:space:]]+ctrl\+a([[:space:]]|$)' "$config"; then
  exit 1
fi
[[ "$(grep -Fxc 'map ctrl+shift+c copy_to_clipboard' "$config")" == 1 ]]
[[ "$(grep -Fxc 'map ctrl+shift+v paste_from_clipboard' "$config")" == 1 ]]
[[ "$(grep -Fxc 'background_opacity 0.92' "$config")" == 1 ]]
if grep -Eiq '(^|[[:space:]])(xclip|xsel|wl-copy)([[:space:]]|$)' "$config"; then
  exit 1
fi

if command -v kitty >/dev/null 2>&1; then
  kitty +runpy \
    'from kitty.options.utils import parse_map; assert len(list(parse_map("ctrl+shift+a launch --stdin-source=@screen_scrollback --type=clipboard"))) == 1'
fi

printf 'OK   Kitty copy-all mapping\n'
