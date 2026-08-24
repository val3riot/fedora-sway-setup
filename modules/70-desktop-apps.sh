#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

SECTION="${1:-all}"
case "$SECTION" in
  all|flatpak|rpm|jetbrains) ;;
  *) die "Sezione non valida: $SECTION. Usa: all, flatpak, rpm oppure jetbrains" ;;
esac

install_rpm_url() {
  local package_name=$1 expected_version=$2 url=$3 output=$4 expected_sha256=$5
  local installed_version
  installed_version="$(rpm -q --qf '%{VERSION}' "$package_name" 2>/dev/null || true)"
  [[ "$installed_version" == "$expected_version" ]] && return 0
  download_verified "$url" "$output" "$expected_sha256"
  sudo dnf install -y "$output"
}

fetch_sha256() {
  local url=$1 output=$2 digest
  download "$url" "$output"
  digest="$(awk 'match($0, /[0-9a-fA-F]{64}/) { print tolower(substr($0, RSTART, RLENGTH)); exit }' "$output")"
  [[ "$digest" =~ ^[0-9a-f]{64}$ ]] || die "SHA-256 non trovato in $url"
  printf '%s\n' "$digest"
}

install_flatpak_app() {
  local app_id=$1
  flatpak info --user "$app_id" >/dev/null 2>&1 && return 0
  flatpak install --user --noninteractive -y flathub "$app_id"
}

if [[ "$SECTION" == all || "$SECTION" == flatpak ]]; then
  install_available_packages flatpak
  command_exists flatpak || die "Flatpak non è disponibile: impossibile installare le app desktop."
  flatpak remote-add --user --if-not-exists flathub "$FLATHUB_REPO_URL"

  install_flatpak_app com.discordapp.Discord
  install_flatpak_app md.obsidian.Obsidian
fi

if [[ "$SECTION" == all || "$SECTION" == rpm ]]; then
  # L'RPM upstream crea /usr/bin/dbeaver nel %post e lo rimuove nel %preun. In
  # upgrade, dnf esegue il nuovo %post prima del vecchio %preun: il link della
  # versione precedente fa fallire `ln -s`. Gestiamo solo quel link esatto e
  # non tocchiamo mai workspace o configurazioni DBeaver.
  dbeaver_launcher=/usr/bin/dbeaver
  if [[ "$(rpm -q --qf '%{VERSION}' dbeaver-ce 2>/dev/null || true)" != "$DBEAVER_VERSION" &&
        -L "$dbeaver_launcher" &&
        "$(readlink "$dbeaver_launcher")" == /usr/share/dbeaver-ce/dbeaver ]]; then
    sudo rm -f -- "$dbeaver_launcher"
  elif [[ -e "$dbeaver_launcher" && ! -L "$dbeaver_launcher" ]]; then
    die "$dbeaver_launcher esiste ma non è il link upstream atteso; non verrà sovrascritto."
  fi
  dbeaver_sha256="$(fetch_sha256 "$DBEAVER_RPM_SHA256_URL" "$TOOLS_DIR/tmp/dbeaver-ce.sha256")"
  install_rpm_url dbeaver-ce "$DBEAVER_VERSION" \
    "$DBEAVER_RPM_URL" \
    "$TOOLS_DIR/tmp/dbeaver-ce-${DBEAVER_VERSION}.x86_64.rpm" \
    "$dbeaver_sha256"
  sudo ln -sfn /usr/share/dbeaver-ce/dbeaver "$dbeaver_launcher"
fi

if [[ "$SECTION" == all || "$SECTION" == rpm ]]; then
  install_available_packages thunderbird libreoffice
fi

if [[ "$SECTION" == all || "$SECTION" == rpm ]]; then
  bruno_metadata="$TOOLS_DIR/tmp/bruno-release.json"
  download "$BRUNO_RELEASES_API_URL" "$bruno_metadata"
  bruno_version="$(jq -r '.tag_name | sub("^v"; "")' "$bruno_metadata")"
  bruno_asset="$(jq -r '[.assets[] | select(.name | test("x86_64.*\\.rpm$|x86_64.*linux.*\\.rpm$"; "i"))][0] // empty' "$bruno_metadata")"
  bruno_url="$(jq -r '.browser_download_url // empty' <<<"$bruno_asset")"
  bruno_digest="$(jq -r '.digest // empty | sub("^sha256:"; "")' <<<"$bruno_asset")"
  [[ -n "$bruno_url" && "$bruno_digest" =~ ^[0-9a-f]{64}$ ]] ||
    die "RPM o digest SHA-256 Bruno non trovato nella release GitHub ufficiale."
  installed_bruno_version="$(rpm -q --qf '%{VERSION}' bruno 2>/dev/null || true)"
  if [[ "$installed_bruno_version" != "$bruno_version" ]]; then
    bruno_rpm="$TOOLS_DIR/tmp/bruno-${bruno_version}.x86_64.rpm"
    download_verified "$bruno_url" "$bruno_rpm" "$bruno_digest"
    if ! sudo dnf install -y "$bruno_rpm"; then
      # Le release upstream correnti hanno un %postun di upgrade difettoso:
      # rimuove dall'alternativa /usr/bin/bruno invece di /opt/Bruno/bruno.
      # Dnf segnala fallimento dopo avere già installato il nuovo payload.
      if [[ "$(rpm -q --qf '%{VERSION}' bruno 2>/dev/null || true)" == "$bruno_version" &&
            -x /opt/Bruno/bruno ]]; then
        warn "Bruno $bruno_version installato; ignorato soltanto l'errore %postun noto della versione precedente."
      else
        die "Installazione Bruno fallita prima di completare il payload atteso."
      fi
    fi
  fi
  [[ -x /opt/Bruno/bruno ]] || die "Payload Bruno ufficiale assente dopo l'installazione."
  if [[ "$(readlink -f /usr/bin/bruno 2>/dev/null || true)" != /opt/Bruno/bruno ]]; then
    die "/usr/bin/bruno non risolve al payload ufficiale atteso."
  fi
fi

if [[ "$SECTION" == all || "$SECTION" == jetbrains ]]; then
  toolbox_base="$TOOLS_DIR/jetbrains-toolbox"
  mkdir -p "$toolbox_base"
  toolbox_metadata="$TOOLS_DIR/tmp/jetbrains-toolbox-release.json"
  download "$JETBRAINS_TOOLBOX_API_URL" "$toolbox_metadata"
  toolbox_version="$(jq -r '.TBA[0].version // empty' "$toolbox_metadata")"
  toolbox_url="$(jq -r '.TBA[0].downloads.linux.link // empty' "$toolbox_metadata")"
  toolbox_checksum_url="$(jq -r '.TBA[0].downloads.linux.checksumLink // empty' "$toolbox_metadata")"
  [[ -n "$toolbox_version" && -n "$toolbox_url" && -n "$toolbox_checksum_url" ]] ||
    die "Metadati JetBrains Toolbox incompleti nell’API ufficiale."
  toolbox_state="$toolbox_base/.workstation-setup-version"
  if [[ "$(cat "$toolbox_state" 2>/dev/null)" != "$toolbox_version" ]]; then
    archive="$TOOLS_DIR/tmp/jetbrains-toolbox-${toolbox_version}.tar.gz"
    toolbox_sha256="$(fetch_sha256 "$toolbox_checksum_url" "$TOOLS_DIR/tmp/jetbrains-toolbox.sha256")"
    download_verified "$toolbox_url" "$archive" "$toolbox_sha256"
    extract_dir="$(mktemp -d)"
    tar -xzf "$archive" -C "$extract_dir" --strip-components=1
    previous_bin="$toolbox_base/bin.workstation-setup-previous"
    rm -rf -- "$previous_bin"
    [[ ! -d "$toolbox_base/bin" ]] || mv -- "$toolbox_base/bin" "$previous_bin"
    mv -- "$extract_dir/bin" "$toolbox_base/bin"
    rm -rf -- "$previous_bin"
    printf '%s\n' "$toolbox_version" > "$toolbox_state"
    rm -r -- "$extract_dir"
  fi
  toolbox_bin="$(find "$toolbox_base" -type f -name jetbrains-toolbox -perm -u+x | head -n1 || true)"
  if [[ -n "$toolbox_bin" ]]; then
    ln -sfn "$toolbox_bin" "$HOME/.local/bin/jetbrains-toolbox"
  fi
fi
