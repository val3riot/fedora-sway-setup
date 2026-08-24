#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

sudo -n true

has_subid_range() {
  local file=$1 user=$2
  awk -F: -v user="$user" '$1 == user && $3 >= 65536 { found=1 } END { exit !found }' "$file" 2>/dev/null
}

find_free_subid_start() {
  local file=$1 minimum=$2 maximum=$3 size=65536
  cut -d: -f2,3 "$file" 2>/dev/null | sort -t: -k1,1n | \
    awk -F: -v cursor="$minimum" -v maximum="$maximum" -v size="$size" '
      $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ {
        start=$1; end=$1+$2-1
        if (cursor+size-1 < start) { print cursor; found=1; exit }
        if (end >= cursor) cursor=end+1
      }
      END {
        if (!found && cursor+size-1 <= maximum) print cursor
      }
    '
}

ensure_subid_range() {
  local type=$1 file=$2 min_key=$3 max_key=$4 flag=$5
  has_subid_range "$file" "$USER" && return 0

  local minimum maximum start end
  minimum="$(awk -v key="$min_key" '$1 == key { print $2; exit }' /etc/login.defs)"
  maximum="$(awk -v key="$max_key" '$1 == key { print $2; exit }' /etc/login.defs)"
  minimum="${minimum:-100000}"
  maximum="${maximum:-600100000}"
  start="$(find_free_subid_start "$file" "$minimum" "$maximum")"
  [[ "$start" =~ ^[0-9]+$ ]] || die "Impossibile trovare un intervallo $type libero di 65536 ID."
  end=$((start + 65535))

  log "Assegnazione $type a $USER: $start-$end"
  sudo usermod "$flag" "$start-$end" "$USER"
  has_subid_range "$file" "$USER" || die "Assegnazione $type non riuscita."
}

setup_rootless_docker() {
  log "Configurazione Docker Engine Rootless per $USER"

  install_available_packages shadow-utils slirp4netns fuse-overlayfs
  command -v newuidmap >/dev/null 2>&1 || die "newuidmap non disponibile: verifica il pacchetto shadow-utils."
  command -v newgidmap >/dev/null 2>&1 || die "newgidmap non disponibile: verifica il pacchetto shadow-utils."

  ensure_subid_range subuid /etc/subuid SUB_UID_MIN SUB_UID_MAX --add-subuids
  ensure_subid_range subgid /etc/subgid SUB_GID_MIN SUB_GID_MAX --add-subgids

  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  [[ -d "$XDG_RUNTIME_DIR" ]] || die "XDG_RUNTIME_DIR non disponibile: esegui il setup da una normale sessione utente Fedora."

  # Un daemon di sistema attivo vanificherebbe l'obiettivo rootless.
  sudo systemctl disable --now docker.service docker.socket containerd.service >/dev/null 2>&1 || true
  sudo rm -f /var/run/docker.sock

  # Rimuove l'accesso equivalente a root lasciato da una precedente v4.
  if getent group docker >/dev/null 2>&1 && id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    sudo gpasswd -d "$USER" docker >/dev/null || true
    warn "Utente rimosso dal gruppo docker. Logout/login necessario per rimuovere il gruppo dalla sessione corrente."
  fi

  command -v dockerd-rootless-setuptool.sh >/dev/null 2>&1 ||
    die "dockerd-rootless-setuptool.sh non trovato; verifica docker-ce-rootless-extras."

  if [[ ! -f "$HOME/.config/systemd/user/docker.service" ]]; then
    dockerd-rootless-setuptool.sh install
  else
    # Assicura che il context esista anche dopo migrazioni/parziali.
    if ! docker context inspect rootless >/dev/null 2>&1; then
      dockerd-rootless-setuptool.sh install --force
    fi
  fi

  systemctl --user enable --now docker.service
  sudo loginctl enable-linger "$USER"

  docker context use rootless >/dev/null
}

log "Configurazione repository Docker ufficiale"
docker_gpg_key="$TOOLS_DIR/tmp/docker-fedora.gpg"
download "$DOCKER_GPG_KEY_URL" "$docker_gpg_key"
actual_fingerprint="$(gpg --show-keys --with-colons "$docker_gpg_key" 2>/dev/null |
  awk -F: '$1 == "fpr" { print $10; exit }')"
[[ "$actual_fingerprint" == "$DOCKER_GPG_FINGERPRINT" ]] ||
  die "Fingerprint GPG Docker inatteso: ${actual_fingerprint:-non rilevato}"
if [[ ! -f /etc/yum.repos.d/docker-ce.repo ]]; then
  if ! dnf config-manager --help >/dev/null 2>&1; then
    install_available_packages dnf5-plugins
  fi
  sudo dnf config-manager addrepo --from-repofile "$DOCKER_REPO_URL"
fi

log "Installazione Docker Engine, Rootless extras, Buildx e Compose V2"
sudo dnf install -y \
  docker-ce docker-ce-cli containerd.io docker-ce-rootless-extras \
  docker-buildx-plugin docker-compose-plugin

setup_rootless_docker

install -m 0755 "$ROOT_DIR/bin/docker-runtime" "$HOME/.local/bin/docker-runtime"

log "Docker configurato"
printf '%s\n' \
  "Engine: installato" \
  "Rootless: abilitato con avvio automatico" \
  "Per verificare: docker info && docker compose version" \
  "Runtime: docker-runtime status|rootless"
