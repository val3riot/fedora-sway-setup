#!/usr/bin/env bash

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mATTENZIONE: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERRORE: %s\033[0m\n' "$*" >&2; exit 1; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

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
  # shellcheck disable=SC1091
  source "$root/config/defaults.env"
  if [[ -f "$root/config/sources.env" ]]; then
    # shellcheck disable=SC1091
    source "$root/config/sources.env"
  fi
  if [[ -f "$root/config/local.env" ]]; then
    # shellcheck disable=SC1091
    source "$root/config/local.env"
  fi
  export TOOLS_DIR PROJECTS_DIR
}

validate_bool_var() {
  local name=$1 value=${!1-}
  case "$value" in
    true|false) ;;
    *) die "$name deve essere true oppure false; valore ricevuto: ${value:-<vuoto>}" ;;
  esac
}

validate_int_range_var() {
  local name=$1 minimum=$2 maximum=$3 value=${!1-}
  [[ "$value" =~ ^[0-9]+$ ]] || die "$name deve essere un intero; valore ricevuto: ${value:-<vuoto>}"
  (( value >= minimum && value <= maximum )) ||
    die "$name deve essere compreso tra $minimum e $maximum; valore ricevuto: $value"
}

validate_config() {
  local bool_name
  local -a bool_vars=(
    RUN_SYSTEM_UPGRADE USE_ENGLISH_XDG_DIRS
    INSTALL_PODMAN INSTALL_DOCKER INSTALL_DOCKER_DESKTOP DOCKER_ROOTLESS DOCKER_ROOTLESS_AUTOSTART
    INSTALL_VIRTUALIZATION VIRTUALIZATION_AUTOSTART INSTALL_VAGRANT CREATE_OPTIONAL_VMS
    INSTALL_VSCODE INSTALL_JETBRAINS_TOOLBOX INSTALL_DBEAVER
    INSTALL_BRUNO INSTALL_DISCORD INSTALL_OBSIDIAN INSTALL_THUNDERBIRD INSTALL_LIBREOFFICE
    INSTALL_DASH_TO_DOCK ENABLE_WINDOW_BUTTONS
    INSTALL_NVM INSTALL_MINICONDA INSTALL_SDKMAN INSTALL_OH_MY_ZSH INSTALL_AGENTS INSTALL_LATEX
    INSTALL_VPN_SUPPORT INSTALL_POWER_MODE POWER_MODE_AUTOSTART
    SET_KITTY_AS_DEFAULT_TERMINAL
    SDKMAN_INSTALL_MAVEN SDKMAN_INSTALL_GRADLE CONDA_AUTO_ACTIVATE_BASE
  )

  for bool_name in "${bool_vars[@]}"; do
    validate_bool_var "$bool_name"
  done

  [[ "$TOOLS_DIR" == /* ]] || die "TOOLS_DIR deve essere un percorso assoluto."
  [[ "$PROJECTS_DIR" == /* ]] || die "PROJECTS_DIR deve essere un percorso assoluto."
  [[ "$VM_ISO_DIR" == /* ]] || die "VM_ISO_DIR deve essere un percorso assoluto."
  [[ "$VM_STORAGE_DIR" == /* ]] || die "VM_STORAGE_DIR deve essere un percorso assoluto."

  case "$POWER_MODE_DEFAULT" in
    dev|quiet|normal|full) ;;
    *) die "POWER_MODE_DEFAULT non valido: $POWER_MODE_DEFAULT" ;;
  esac

  validate_int_range_var POWER_MODE_DEV_MAX 20 100
  validate_int_range_var POWER_MODE_QUIET_MAX 20 100
  validate_int_range_var POWER_MODE_MIN_PERF 0 100
  (( POWER_MODE_MIN_PERF <= POWER_MODE_DEV_MAX )) ||
    die "POWER_MODE_MIN_PERF non può superare POWER_MODE_DEV_MAX."
  (( POWER_MODE_MIN_PERF <= POWER_MODE_QUIET_MAX )) ||
    die "POWER_MODE_MIN_PERF non può superare POWER_MODE_QUIET_MAX."

  local source_name
  local -a source_vars=(
    OH_MY_ZSH_COMMIT OH_MY_ZSH_INSTALL_URL OH_MY_ZSH_INSTALL_SHA256
    STARSHIP_VERSION STARSHIP_ARCHIVE_URL STARSHIP_ARCHIVE_SHA256
    SDKMAN_INSTALL_URL NVM_VERSION NVM_INSTALL_URL NVM_INSTALL_SHA256
    MINICONDA_VERSION MINICONDA_INSTALLER_URL MINICONDA_INSTALLER_SHA256
    CODEX_VERSION CODEX_INSTALL_URL CODEX_INSTALL_SHA256
    CLAUDE_VERSION CLAUDE_INSTALL_URL CLAUDE_INSTALL_SHA256
    COPILOT_VERSION COPILOT_INSTALL_URL COPILOT_INSTALL_SHA256
    DOCKER_REPO_URL DOCKER_GPG_KEY_URL DOCKER_GPG_FINGERPRINT DOCKER_DESKTOP_VERSION
    DOCKER_DESKTOP_RPM_URL DOCKER_DESKTOP_RPM_SHA256
    VSCODE_GPG_KEY_URL VSCODE_REPO_BASEURL
    FLATHUB_REPO_URL DBEAVER_VERSION DBEAVER_RPM_URL DBEAVER_RPM_SHA256_URL
    BRUNO_RELEASES_API_URL JETBRAINS_TOOLBOX_API_URL
  )
  for source_name in "${source_vars[@]}"; do
    [[ -n "${!source_name-}" ]] || die "$source_name non può essere vuoto (config/sources.env)."
  done

  [[ "$OH_MY_ZSH_COMMIT" =~ ^[0-9a-f]{40}$ ]] ||
    die "OH_MY_ZSH_COMMIT deve essere uno SHA Git completo."
  for digest_name in OH_MY_ZSH_INSTALL_SHA256 STARSHIP_ARCHIVE_SHA256 NVM_INSTALL_SHA256 \
    MINICONDA_INSTALLER_SHA256 CODEX_INSTALL_SHA256 CLAUDE_INSTALL_SHA256 \
    COPILOT_INSTALL_SHA256 DOCKER_DESKTOP_RPM_SHA256; do
    [[ "${!digest_name}" =~ ^[0-9a-f]{64}$ ]] || die "$digest_name deve essere uno SHA-256 valido."
  done
}

install_available_packages() {
  local package
  local -a available=()
  local -a missing=()

  for package in "$@"; do
    if rpm -q "$package" >/dev/null 2>&1; then
      printf '  già installato: %s\n' "$package"
    elif dnf -q repoquery --available "$package" >/dev/null 2>&1; then
      available+=("$package")
    else
      missing+=("$package")
    fi
  done

  if ((${#available[@]})); then
    sudo dnf install -y "${available[@]}"
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
