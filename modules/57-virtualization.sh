#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

sudo -n true
log "Installazione stack VM KVM/QEMU + libvirt + virt-manager"
install_available_packages \
  qemu-kvm libvirt libvirt-daemon-kvm libvirt-daemon-config-network \
  virt-manager virt-install virt-viewer \
  edk2-ovmf swtpm swtpm-tools libosinfo

log "Installazione Vagrant con provider libvirt"
install_available_packages vagrant vagrant-libvirt

if [[ ! -e /dev/kvm ]]; then
  warn "/dev/kvm non presente: abilita Intel VT-x/AMD-V nel firmware e riavvia. Le VM senza KVM sarebbero molto più lente."
fi

for group in kvm libvirt; do
  if getent group "$group" >/dev/null 2>&1 && ! id -nG "$USER" | tr ' ' '\n' | grep -qx "$group"; then
    sudo usermod -aG "$group" "$USER"
    warn "Utente aggiunto al gruppo $group: logout/login necessario per applicare il gruppo alla sessione."
  fi
done

if systemctl list-unit-files libvirtd.service --no-legend 2>/dev/null | grep -q '^libvirtd.service'; then
  sudo systemctl enable --now libvirtd.service
else
  for unit in virtqemud.socket virtnetworkd.socket virtstoraged.socket; do
    if systemctl list-unit-files "$unit" --no-legend 2>/dev/null | grep -q "^$unit"; then
      sudo systemctl enable --now "$unit"
    fi
  done
fi

if sudo virsh net-info default >/dev/null 2>&1; then
  sudo virsh net-autostart default >/dev/null 2>&1 || true
  sudo virsh net-start default >/dev/null 2>&1 || true
fi

log "Virtualizzazione configurata"
printf '%s\n' \
  "GUI: virt-manager" \
  "CLI: virsh, virt-install" \
  "DevOps VM lifecycle: Vagrant + libvirt" \
  "Firmware VM: UEFI/OVMF" \
  "TPM software: swtpm (utile per Windows 11)"
