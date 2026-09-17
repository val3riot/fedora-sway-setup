#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

failed=0
ok() { printf 'OK   %-24s %s\n' "$1" "$2"; }
warn_audit() { printf 'WARN %-24s %s\n' "$1" "$2"; }
fail_audit() { printf 'FAIL %-24s %s\n' "$1" "$2" >&2; failed=1; }

check_rpm_command() {
  local command_name=$1 expected_package=$2 path resolved owner
  path="$(type -P "$command_name" 2>/dev/null || true)"
  [[ -n "$path" ]] || { fail_audit "$command_name" 'eseguibile assente'; return; }
  resolved="$(readlink -f "$path")"
  owner="$(rpm -qf "$resolved" 2>/dev/null || true)"
  if [[ "$owner" == "$expected_package"-[0-9]* || "$owner" == "$expected_package" ]]; then
    ok "$command_name" "$path | RPM $owner"
  else
    fail_audit "$command_name" "$path | proprietario inatteso: ${owner:-nessun RPM}"
  fi
}

check_fedora_package() {
  local package=$1 vendor
  vendor="$(rpm -q --qf '%{VENDOR}' "$package" 2>/dev/null || true)"
  if [[ "$vendor" == 'Fedora Project' ]]; then
    ok "$package source" 'Fedora official repository'
  else
    fail_audit "$package source" "vendor RPM inatteso: ${vendor:-pacchetto assente}"
  fi
}

printf '%s\n' 'Provenance desktop locale (nessuna richiesta Internet)'

# Eseguibili desktop di base da repository Fedora
check_rpm_command git git-core
check_rpm_command zsh zsh
check_rpm_command kitty kitty
check_rpm_command sway sway
check_rpm_command swaylock swaylock
check_rpm_command grim grim
check_rpm_command slurp slurp
check_rpm_command wl-copy wl-clipboard

for fedora_package in git-core zsh zsh-syntax-highlighting zsh-autosuggestions kitty \
  sway swaylock grim slurp wl-clipboard pipewire wireplumber NetworkManager NetworkManager-tui bluez greetd; do
  if rpm -q "$fedora_package" >/dev/null 2>&1; then
    check_fedora_package "$fedora_package"
  fi
done

# Quickshell
if command -v quickshell >/dev/null 2>&1; then
  check_rpm_command quickshell quickshell
  check_fedora_package quickshell
  if rpm -V quickshell >/dev/null 2>&1; then
    ok 'Quickshell RPM integrity' 'rpm -V riuscito'
  else
    fail_audit 'Quickshell RPM integrity' 'file RPM modificati o mancanti'
  fi
fi

# Starship upstream verified binary
if [[ "$(type -P starship 2>/dev/null || true)" == "$HOME/.local/bin/starship" ]]; then
  ok Starship "$HOME/.local/bin/starship | archivio upstream verificato"
else
  fail_audit Starship 'path inatteso o assente'
fi

# BlueTUI official release
if [[ "$(type -P bluetui 2>/dev/null || true)" == "$HOME/.local/bin/bluetui" ]]; then
  ok BlueTUI "$HOME/.local/bin/bluetui | release upstream verificata"
else
  warn_audit BlueTUI 'bluetui non trovato in ~/.local/bin'
fi

# Oh My Zsh git upstream
omz_origin="$(git -C "$HOME/.oh-my-zsh" remote get-url origin 2>/dev/null || true)"
if [[ "$omz_origin" == 'https://github.com/ohmyzsh/ohmyzsh.git' ]]; then
  ok 'Oh My Zsh' "$omz_origin"
else
  warn_audit 'Oh My Zsh' "origin inattesa: ${omz_origin:-assente}"
fi

# Nessun repository COPR abilitato
copr_enabled=false
for repo_file in /etc/yum.repos.d/_copr*.repo; do
  [[ -r "$repo_file" ]] || continue
  if awk -F= '$1 == "enabled" && $2 == "1" { found=1 } END { exit !found }' "$repo_file"; then
    fail_audit 'COPR enabled' "$repo_file"
    copr_enabled=true
  fi
done
[[ "$copr_enabled" == true ]] || ok 'COPR enabled' 'nessuno'

exit "$failed"
