#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

VM_STORAGE_DIR=/var/lib/libvirt/images

usage() {
  cat <<'EOF'
Uso: create-vms.sh NOME ISO [opzioni]

Crea un guest libvirt persistente da una ISO locale. Le VM già esistenti non
vengono modificate. L'installazione si completa graficamente in virt-manager.

Opzioni:
  --memory MIB       Memoria RAM (predefinita: 4096)
  --vcpus NUMERO     CPU virtuali (predefinite: 2)
  --disk-size GIB    Dimensione del disco (predefinita: 40)
  --osinfo ID        Identificativo libosinfo (predefinito: rilevamento automatico)
  --uefi             Usa firmware UEFI
  --tpm              Aggiunge un TPM 2.0 virtuale
  --help, -h         Mostra questa guida
EOF
}

if (( $# == 0 )) || [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  usage
  (( $# == 0 )) && exit 2 || exit 0
fi
(( $# >= 2 )) || die "Uso: create-vms.sh NOME ISO [opzioni]."

name=$1
iso=$2
shift 2
memory=4096
vcpus=2
disk_size=40
os_name='detect=on,require=off'
declare -a extra_args=()

require_positive_integer() {
  local option=$1 value=${2:-}
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || die "$option richiede un intero positivo."
}

while (( $# )); do
  case "$1" in
    --memory)
      (( $# >= 2 )) || die "Valore mancante per --memory."
      require_positive_integer --memory "$2"
      memory=$2
      shift 2
      ;;
    --vcpus)
      (( $# >= 2 )) || die "Valore mancante per --vcpus."
      require_positive_integer --vcpus "$2"
      vcpus=$2
      shift 2
      ;;
    --disk-size)
      (( $# >= 2 )) || die "Valore mancante per --disk-size."
      require_positive_integer --disk-size "$2"
      disk_size=$2
      shift 2
      ;;
    --osinfo)
      (( $# >= 2 )) || die "Valore mancante per --osinfo."
      [[ -n "$2" && "$2" != -* ]] || die "Valore non valido per --osinfo."
      os_name=$2
      shift 2
      ;;
    --uefi) extra_args+=(--boot uefi); shift ;;
    --tpm) extra_args+=(--tpm 'backend.type=emulator,backend.version=2.0,model=tpm-crb'); shift ;;
    *) die "Opzione non valida: $1" ;;
  esac
done

[[ "$name" =~ ^[[:alnum:]][[:alnum:]_.-]*$ ]] ||
  die "Nome VM non valido: usa solo lettere, numeri, punto, trattino e underscore."
[[ -r "$iso" ]] || die "ISO non leggibile: $iso"

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
  if "${libvirt[@]}" dominfo "$name" >/dev/null 2>&1; then
    printf 'SKIP %-12s esiste già\n' "$name"
    return
  fi

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
    "${extra_args[@]}"
  printf 'OK   %-12s avvia la console con: virt-manager\n' "$name"
}

ensure_network
if [[ ! -d "$VM_STORAGE_DIR" ]]; then
  command_exists sudo || die "La directory non esiste e sudo non è disponibile: $VM_STORAGE_DIR"
  sudo install -d -m 0755 "$VM_STORAGE_DIR"
fi

create_vm
