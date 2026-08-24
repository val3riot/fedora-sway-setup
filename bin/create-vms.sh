#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

VM_ISO_DIR="$HOME/ISO"
VM_DEBIAN_ISO="$VM_ISO_DIR/debian.iso"
VM_FEDORA_ISO="$VM_ISO_DIR/fedora.iso"
VM_WINDOWS11_ISO="$VM_ISO_DIR/windows11.iso"
VM_STORAGE_DIR=/var/lib/libvirt/images

usage() {
  cat <<'EOF'
Uso: create-vms.sh [all|debian|fedora|windows11 ...]

Crea guest libvirt persistenti usando le ISO in ~/ISO.
Le VM già esistenti non vengono modificate. Le installazioni si completano
graficamente in virt-viewer/virt-manager.
EOF
}

(( $# )) || set -- all
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  usage
  exit 0
fi

command_exists virsh || die "virsh non trovato: esegui prima ./install.sh --dev."
command_exists virt-install || die "virt-install non trovato: esegui prima ./install.sh --dev."

declare -a libvirt=(virsh -c qemu:///system)
declare -a elevate=()
if ! "${libvirt[@]}" list >/dev/null 2>&1; then
  command_exists sudo || die "Accesso a qemu:///system negato e sudo non disponibile."
  elevate=(sudo)
  libvirt=(sudo virsh -c qemu:///system)
fi

ensure_network() {
  if "${libvirt[@]}" net-info default >/dev/null 2>&1; then
    "${libvirt[@]}" net-start default >/dev/null 2>&1 || true
    return
  fi
  die "Rete libvirt 'default' non disponibile; riesegui il modulo di virtualizzazione."
}

create_vm() {
  local name=$1 iso=$2 memory=$3 vcpus=$4 disk_size=$5 os_name=$6
  shift 6

  if "${libvirt[@]}" dominfo "$name" >/dev/null 2>&1; then
    printf 'SKIP %-12s esiste già\n' "$name"
    return
  fi
  [[ -r "$iso" ]] || die "ISO non leggibile per $name: $iso"

  log "Creazione $name"
  "${elevate[@]}" virt-install \
    --connect qemu:///system \
    --name "$name" \
    --memory "$memory" \
    --vcpus "$vcpus" \
    --cpu host-passthrough \
    --disk "path=$VM_STORAGE_DIR/$name.qcow2,size=$disk_size,format=qcow2,bus=virtio" \
    --cdrom "$iso" \
    --network network=default,model=virtio \
    --graphics spice \
    --video virtio \
    --osinfo "$os_name" \
    --noautoconsole \
    "$@"
  printf 'OK   %-12s avvia la console con: virt-manager\n' "$name"
}

ensure_network
if [[ ! -d "$VM_STORAGE_DIR" ]]; then
  command_exists sudo || die "La directory non esiste e sudo non è disponibile: $VM_STORAGE_DIR"
  sudo install -d -m 0755 "$VM_STORAGE_DIR"
fi

declare -a requested=("$@")
if [[ " ${requested[*]} " == *" all "* ]]; then
  requested=(debian fedora windows11)
fi

# Evita una creazione parziale quando viene richiesto un gruppo di VM.
for guest in "${requested[@]}"; do
  case "$guest" in
    debian)
      "${libvirt[@]}" dominfo debian >/dev/null 2>&1 ||
        [[ -r "$VM_DEBIAN_ISO" ]] || die "ISO non leggibile per debian: $VM_DEBIAN_ISO"
      ;;
    fedora)
      "${libvirt[@]}" dominfo fedora >/dev/null 2>&1 ||
        [[ -r "$VM_FEDORA_ISO" ]] || die "ISO non leggibile per fedora: $VM_FEDORA_ISO"
      ;;
    windows11|w11)
      "${libvirt[@]}" dominfo windows11 >/dev/null 2>&1 ||
        [[ -r "$VM_WINDOWS11_ISO" ]] || die "ISO non leggibile per windows11: $VM_WINDOWS11_ISO"
      ;;
    *) usage >&2; die "Guest non valido: $guest" ;;
  esac
done

for guest in "${requested[@]}"; do
  case "$guest" in
    debian)
      create_vm debian "$VM_DEBIAN_ISO" 4096 2 40 detect=on,require=off
      ;;
    fedora)
      create_vm fedora "$VM_FEDORA_ISO" 4096 2 50 detect=on,require=off
      ;;
    windows11|w11)
      create_vm windows11 "$VM_WINDOWS11_ISO" 8192 4 80 win11 \
        --boot uefi \
        --tpm backend.type=emulator,backend.version=2.0,model=tpm-crb
      ;;
    *)
      usage >&2
      die "Guest non valido: $guest"
      ;;
  esac
done
