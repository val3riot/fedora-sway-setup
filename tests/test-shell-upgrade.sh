#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT

test_root="$test_dir/repo"
test_home="$test_dir/home"
mkdir -p \
  "$test_root/config" "$test_root/lib" "$test_root/modules" "$test_root/templates" \
  "$test_home/.config/workstation-setup" "$test_home/.oh-my-zsh"

install -m 0644 "$REPO_DIR/lib/common.sh" "$test_root/lib/common.sh"
install -m 0644 "$REPO_DIR/templates/zshrc" "$test_root/templates/zshrc"
install -m 0755 "$REPO_DIR/modules/20-shell.sh" "$test_root/modules/20-shell.sh"
install -m 0644 \
  "$REPO_DIR/tests/fixtures/legacy-env.zsh" \
  "$test_home/.config/workstation-setup/env.zsh"
sed -i -e 's/__SSH__/ssh/g' -e 's/__KITTY_WINDOW_ID__/KITTY_WINDOW_ID/g' \
  "$test_home/.config/workstation-setup/env.zsh"

HOME="$test_home" ROOT_DIR="$test_root" PROFILE=base \
  bash "$test_root/modules/20-shell.sh" >/dev/null

env_file="$test_home/.config/workstation-setup/env.zsh"
if grep -Fq 'kitten ssh' "$env_file"; then
  printf '%s\n' 'FAIL override kitten ssh ancora presente dopo upgrade' >&2
  exit 1
fi
HOME="$test_home" zsh -fc \
  'source "$1"; [[ "$(whence -w ssh)" == "ssh: command" ]]' \
  zsh "$env_file"

printf '%s\n' 'OK   upgrade shell ripristina OpenSSH standard'
