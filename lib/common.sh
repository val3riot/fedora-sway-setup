#!/usr/bin/env bash

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mATTENZIONE: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERRORE: %s\033[0m\n' "$*" >&2; exit 1; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

SUDO_KEEPALIVE_PID=""

start_sudo_keepalive() {
  command_exists sudo || die "sudo non è installato."
  if ! sudo -n true >/dev/null 2>&1; then
    printf '%s\n' "Autenticazione amministrativa richiesta una sola volta per il setup."
    sudo -v || die "Autenticazione sudo non riuscita."
  fi

  # Mantiene valido il ticket senza leggere da stdin: eventuali rinnovi falliti
  # vengono ignorati e il processo termina insieme allo script principale.
  while true; do
    sleep 50
    sudo -n true >/dev/null 2>&1 || exit 0
  done &
  SUDO_KEEPALIVE_PID=$!
}

stop_sudo_keepalive() {
  [[ -n "${SUDO_KEEPALIVE_PID:-}" ]] || return 0
  kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true
  wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  SUDO_KEEPALIVE_PID=""
}

require_fedora_44() {
  [[ -r /etc/os-release ]] || die "Impossibile leggere /etc/os-release"
  # shellcheck disable=SC1091
  source /etc/os-release
  [[ "${ID:-}" == "fedora" ]] || die "Questo setup supporta Fedora, trovato: ${ID:-sconosciuto}"
  if [[ "${VERSION_ID:-}" != "44" ]]; then
    warn "Setup progettato per Fedora 44; versione rilevata: ${VERSION_ID:-sconosciuta}."
  fi
  [[ "$(uname -m)" == "x86_64" ]] || die "Al momento è supportata solo architettura x86_64."
}

load_config() {
  local root=$1
  TOOLS_DIR="$HOME/Tools"
  PROJECTS_DIR="$HOME/Progetti"
  if [[ -f "$root/config/versions.env" ]]; then
    # shellcheck disable=SC1091
    source "$root/config/versions.env"
  fi
  if [[ -f "$root/config/sources.env" ]]; then
    # shellcheck disable=SC1091
    source "$root/config/sources.env"
  fi
  export TOOLS_DIR PROJECTS_DIR
}

validate_config() {
  local source_name
  local -a source_vars=(
    OH_MY_ZSH_COMMIT OH_MY_ZSH_INSTALL_URL OH_MY_ZSH_INSTALL_SHA256
    STARSHIP_VERSION STARSHIP_ARCHIVE_URL STARSHIP_ARCHIVE_SHA256
    BLUETUI_VERSION BLUETUI_X86_64_URL BLUETUI_X86_64_SHA256
  )
  for source_name in "${source_vars[@]}"; do
    [[ -n "${!source_name-}" ]] || die "$source_name non può essere vuoto (sources.env/versions.env)."
  done

  [[ "$OH_MY_ZSH_COMMIT" =~ ^[0-9a-f]{40}$ ]] ||
    die "OH_MY_ZSH_COMMIT deve essere uno SHA Git completo."
  for digest_name in OH_MY_ZSH_INSTALL_SHA256 STARSHIP_ARCHIVE_SHA256 BLUETUI_X86_64_SHA256; do
    [[ "${!digest_name}" =~ ^[0-9a-f]{64}$ ]] || die "$digest_name deve essere uno SHA-256 valido."
  done
}

install_available_packages() {
  local package
  local -a pending=()
  local -a missing=()

  for package in "$@"; do
    if rpm -q "$package" >/dev/null 2>&1; then
      printf '  già installato: %s\n' "$package"
    else
      pending+=("$package")
    fi
  done

  if ((${#pending[@]})); then
    log "Installazione/verifica di ${#pending[@]} pacchetti con DNF"
    if ! sudo -n dnf install -y --skip-unavailable "${pending[@]}" </dev/null; then
      warn "Tentativo DNF fallito o interrotto; nuovo tentativo in corso..."
      sudo -n dnf install -y --skip-unavailable "${pending[@]}" </dev/null || true
    fi
    for package in "${pending[@]}"; do
      rpm -q "$package" >/dev/null 2>&1 || missing+=("$package")
    done
  fi
  if ((${#missing[@]})); then
    warn "Pacchetti non trovati nei repository abilitati: ${missing[*]}"
  fi
}

append_line_once() {
  local line=$1 file=$2
  mkdir -p "$(dirname "$file")"
  touch "$file"
  grep -Fqx "$line" "$file" || printf '%s\n' "$line" >> "$file"
}

install_managed_config() {
  local source_file=$1 target_file=$2 marker=$3 backup="${2}.workstation-setup.bak"
  mkdir -p "$(dirname "$target_file")"
  if [[ -e "$target_file" ]] && ! grep -Fq "$marker" "$target_file"; then
    [[ -e "$backup" ]] || cp -p "$target_file" "$backup"
  fi
  install -m 0644 "$source_file" "$target_file"
}

download() {
  local url=$1 output=$2
  mkdir -p "$(dirname "$output")"
  curl --fail --location --retry 3 --retry-delay 2 --output "$output" "$url"
}

download_verified() {
  local url=$1 output=$2 expected_sha256=$3
  download "$url" "$output"
  printf '%s  %s\n' "$expected_sha256" "$output" | sha256sum --check --status ||
    die "Checksum SHA-256 non valido per $url"
}
