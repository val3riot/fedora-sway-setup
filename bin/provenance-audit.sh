#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

AGENTS_ROOT="$TOOLS_DIR/Agents"
CLAUDE_CONFIG_DIR="$AGENTS_ROOT/claude"
COPILOT_HOME="$AGENTS_ROOT/copilot"

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

check_unique_command() {
  local command_name=$1 count paths
  paths="$(type -a -p "$command_name" 2>/dev/null | while read -r path; do readlink -f "$path"; done | sort -u)"
  count="$(grep -c . <<<"$paths" || true)"
  if [[ "$count" == 1 ]]; then
    ok "$command_name copies" "una provenienza eseguibile"
  else
    fail_audit "$command_name copies" "${count:-0} destinazioni distinte"
  fi
}

check_agent() {
  local name=$1 expected_pattern=$2 path resolved
  path="$(type -P "$name" 2>/dev/null || true)"
  [[ -n "$path" ]] || { fail_audit "$name" 'agente assente'; return; }
  resolved="$(readlink -f "$path")"
  # Il secondo operando è intenzionalmente un pattern limitato definito dal chiamante.
  # shellcheck disable=SC2053
  if [[ "$path" == "$HOME/.local/bin/$name" && "$resolved" == $expected_pattern ]]; then
    ok "$name" "$path -> $resolved"
  else
    fail_audit "$name" "launcher o destinazione inattesi: $path -> $resolved"
  fi
  check_unique_command "$name"
}

printf '%s\n' 'Provenance locale (nessuna richiesta Internet)'
check_rpm_command git git-core
check_rpm_command zsh zsh
check_rpm_command kitty kitty
check_rpm_command tmux tmux
check_rpm_command ssh openssh-clients
check_rpm_command docker docker-ce-cli
check_rpm_command code code
check_rpm_command dbeaver dbeaver-ce
check_rpm_command bruno bruno
check_rpm_command vagrant vagrant
check_rpm_command virsh libvirt-client
check_rpm_command virt-manager virt-manager
check_rpm_command tailscale tailscale
for fedora_package in git-core zsh zsh-syntax-highlighting zsh-autosuggestions kitty tmux \
  openssh-clients vagrant libvirt-client virt-manager; do
  check_fedora_package "$fedora_package"
done

if rpm -q docker-desktop >/dev/null 2>&1; then
  if [[ "$(readlink /usr/local/bin/docker 2>/dev/null || true)" == /usr/bin/docker ]]; then
    ok 'Docker Desktop link' '/usr/local/bin/docker -> /usr/bin/docker (previsto dal vendor)'
  else
    fail_audit 'Docker Desktop link' '/usr/local/bin/docker non è il link vendor atteso'
  fi
else
  ok 'Docker Desktop link' 'non richiesto: Docker Desktop non installato'
fi

if [[ "$(type -P starship 2>/dev/null || true)" == "$HOME/.local/bin/starship" ]]; then
  ok Starship "$HOME/.local/bin/starship | archivio upstream verificato"
else
  fail_audit Starship 'path inatteso o assente'
fi

if [[ -x "$TOOLS_DIR/sdkman/candidates/java/current/bin/java" ]]; then
  ok Java "$TOOLS_DIR/sdkman | SDKMAN/Temurin"
else
  fail_audit Java 'SDKMAN/Temurin assente'
fi
if [[ -x "$TOOLS_DIR/sdkman/candidates/maven/current/bin/mvn" ]]; then
  ok Maven "$TOOLS_DIR/sdkman | SDKMAN"
else
  fail_audit Maven 'SDKMAN Maven assente'
fi
if [[ -s "$TOOLS_DIR/nvm/nvm.sh" ]]; then
  ok Node "$TOOLS_DIR/nvm | nvm-sh/nvm"
else
  fail_audit Node 'NVM assente'
fi
if [[ -x "$TOOLS_DIR/miniconda3/bin/conda" ]]; then
  ok Miniconda "$TOOLS_DIR/miniconda3 | Anaconda"
else
  fail_audit Miniconda 'Miniconda assente'
fi

omz_origin="$(git -C "$HOME/.oh-my-zsh" remote get-url origin 2>/dev/null || true)"
if [[ "$omz_origin" == 'https://github.com/ohmyzsh/ohmyzsh.git' ]]; then
  ok 'Oh My Zsh' "$omz_origin"
else
  fail_audit 'Oh My Zsh' "origin inattesa: ${omz_origin:-assente}"
fi
nvm_origin="$(git -C "$TOOLS_DIR/nvm" remote get-url origin 2>/dev/null || true)"
if [[ "$nvm_origin" == 'https://github.com/nvm-sh/nvm.git' ]]; then
  ok NVM "$nvm_origin"
else
  fail_audit NVM "origin inattesa: ${nvm_origin:-assente}"
fi

check_agent codex "$HOME/.codex/packages/standalone/releases/"'*/bin/codex'
check_agent claude "$HOME/.local/share/claude/versions/"'*'
check_agent copilot "$HOME/.local/bin/copilot"

if [[ -s "$TOOLS_DIR/nvm/nvm.sh" ]]; then
  # shellcheck disable=SC1090
  source "$TOOLS_DIR/nvm/nvm.sh"
  for package in '@openai/codex' '@anthropic-ai/claude-code' '@github/copilot'; do
    if npm list --global --depth=0 --json 2>/dev/null |
      jq -e --arg package "$package" '.dependencies[$package] != null' >/dev/null; then
      fail_audit 'legacy npm agent' "$package ancora installato"
    else
      ok 'legacy npm agent' "$package assente"
    fi
  done
fi

for repo_check in \
  '/etc/yum.repos.d/docker-ce.repo|download.docker.com/linux/fedora|gpgcheck=1' \
  '/etc/yum.repos.d/tailscale.repo|pkgs.tailscale.com/stable/fedora|gpgcheck=1' \
  '/etc/yum.repos.d/vscode.repo|packages.microsoft.com/yumrepos/vscode|gpgcheck=1'; do
  IFS='|' read -r repo_file expected_url expected_gpg <<<"$repo_check"
  if [[ -r "$repo_file" ]] && grep -Fq "$expected_url" "$repo_file" && grep -Fq "$expected_gpg" "$repo_file"; then
    ok 'RPM vendor repo' "$repo_file"
  else
    fail_audit 'RPM vendor repo' "$repo_file non conforme"
  fi
done

copr_enabled=false
for repo_file in /etc/yum.repos.d/_copr*.repo; do
  [[ -r "$repo_file" ]] || continue
  if awk -F= '$1 == "enabled" && $2 == "1" { found=1 } END { exit !found }' "$repo_file"; then
    fail_audit 'COPR enabled' "$repo_file"
    copr_enabled=true
  fi
done
[[ "$copr_enabled" == true ]] || ok 'COPR enabled' 'nessuno'

for app in com.discordapp.Discord md.obsidian.Obsidian; do
  if flatpak info --user "$app" >/dev/null 2>&1; then
    origin="$(flatpak info --user --show-origin "$app")"
    if [[ "$origin" == flathub ]]; then
      warn_audit "$app" 'Flathub: community/terza parte documentata'
    else
      fail_audit "$app" "origin inattesa: $origin"
    fi
  else
    fail_audit "$app" 'Flatpak assente'
  fi
done

[[ -x /usr/local/bin/ollama ]] &&
  warn_audit Ollama '/usr/local/bin/ollama manuale; fonte storica non attestabile localmente' || true

for auth_check in \
  "Codex|$HOME/.codex/auth.json" \
  "Claude|$CLAUDE_CONFIG_DIR" \
  "Copilot|$COPILOT_HOME/config.json"; do
  IFS='|' read -r label auth_path <<<"$auth_check"
  [[ -e "$auth_path" ]] && present=yes || present=no
  printf 'INFO %-24s authentication present: %s\n' "$label" "$present"
done

exit "$failed"
