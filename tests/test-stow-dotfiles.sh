#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Verify syntax
bash -n "$ROOT_DIR/bin/stow-dotfiles"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$ROOT_DIR/bin/stow-dotfiles"
fi

# Verify dotfiles packages exist
required_packages=(
  shell
  kitty
  sway
  swaylock
  waybar
  quickshell
  systemd-user
  scripts
  desktop-theme
)

for pkg in "${required_packages[@]}"; do
  [[ -d "$ROOT_DIR/dotfiles/$pkg" ]] || {
    printf 'FAIL dotfiles package mancante: %s\n' "$pkg" >&2
    exit 1
  }
done

# Verify key dotfiles are present
test -f "$ROOT_DIR/dotfiles/shell/.zshrc"
test -f "$ROOT_DIR/dotfiles/shell/.config/starship.toml"
test -f "$ROOT_DIR/dotfiles/kitty/.config/kitty/kitty.conf"
test -f "$ROOT_DIR/dotfiles/sway/.config/sway/config"
test -f "$ROOT_DIR/dotfiles/swaylock/.config/swaylock/config"
test -f "$ROOT_DIR/dotfiles/waybar/.config/waybar/config"
test -f "$ROOT_DIR/dotfiles/waybar/.config/waybar/style.css"
test -f "$ROOT_DIR/dotfiles/systemd-user/.config/systemd/user/workstation-bar.service"
test -f "$ROOT_DIR/dotfiles/desktop-theme/.config/gtk-3.0/settings.ini"

# Check portability: no hardcoded /home/ username paths inside versioned dotfiles
! grep -rn --exclude-dir='__pycache__' --exclude='*.pyc' '/home/[a-zA-Z0-9_-]\+' "$ROOT_DIR/dotfiles" 2>/dev/null || {
  printf 'FAIL percorsi utente hardcoded trovati in dotfiles/\n' >&2
  exit 1
}

# Isolated test environment for stow-dotfiles
test_tmp="$(mktemp -d)"
trap 'rm -rf -- "$test_tmp"' EXIT
test_home="$test_tmp/home"
mkdir -p "$test_home"

# 1. Apply in empty test home
HOME="$test_home" "$ROOT_DIR/bin/stow-dotfiles" apply shell kitty

# Verify symlinks created
test -L "$test_home/.zshrc"
test -L "$test_home/.config/starship.toml"
test -L "$test_home/.config/kitty/kitty.conf"

# Verify targets point to repository
[[ "$(readlink -f "$test_home/.zshrc")" == "$ROOT_DIR/dotfiles/shell/.zshrc" ]]
[[ "$(readlink -f "$test_home/.config/kitty/kitty.conf")" == "$ROOT_DIR/dotfiles/kitty/.config/kitty/kitty.conf" ]]

# 2. Check returns 0
HOME="$test_home" "$ROOT_DIR/bin/stow-dotfiles" check shell kitty >/dev/null

# 3. Idempotent apply
HOME="$test_home" "$ROOT_DIR/bin/stow-dotfiles" apply shell kitty >/dev/null

# 4. Backup behavior: create conflicting regular file in sway config
mkdir -p "$test_home/.config/sway"
printf '%s\n' '# custom sway config' > "$test_home/.config/sway/config"

HOME="$test_home" "$ROOT_DIR/bin/stow-dotfiles" apply sway >/dev/null
test -L "$test_home/.config/sway/config"
[[ "$(readlink -f "$test_home/.config/sway/config")" == "$ROOT_DIR/dotfiles/sway/.config/sway/config" ]]

# Verify backup was created
backup_count="$(find "$test_home/.local/state/fedora-workstation-setup/stow-migration" -type f -name 'config' | wc -l)"
[[ "$backup_count" -ge 1 ]]

# 5. Remove package
HOME="$test_home" "$ROOT_DIR/bin/stow-dotfiles" remove kitty >/dev/null
[[ ! -e "$test_home/.config/kitty/kitty.conf" ]]

printf '%s\n' 'OK   GNU Stow dotfiles e gestione symlink'
