#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"
[[ "${CONFIG_QUICKSHELL:-false}" == true ]] || exit 0

log 'Quickshell: verifica migrazione Sway prima di modificare file o pacchetti'
python3 "$ROOT_DIR/bin/configure-quickshell.py" --check
for target in "$HOME/.local/bin/workstation-bar.sh" "$HOME/.config/systemd/user/workstation-bar.service"; do
  if [[ -L "$target" ]] || { [[ -e "$target" ]] && ! grep -Fq '# workstation-setup: managed bar' "$target"; }; then
    die "Helper/servizio personale da preservare: $target"
  fi
done
# Restrict the transaction to Fedora's official repositories, including deps.
# No implicit COPR fallback and no acceptance of an existing third-party RPM.
if rpm -q quickshell >/dev/null 2>&1; then
  [[ "$(rpm -q --qf '%{VENDOR}' quickshell)" == 'Fedora Project' ]] ||
    die 'Quickshell installato da fonte non Fedora: risolvere la provenance prima di continuare.'
fi
log 'Quickshell: installazione RPM Fedora official (fedora, updates)'
sudo dnf --repo=fedora --repo=updates install -y quickshell kitty python3-gobject NetworkManager-libnm grim slurp wl-clipboard brightnessctl libnotify swaylock
command_exists quickshell || die 'Quickshell non disponibile dopo installazione.'
[[ "$(rpm -q --qf '%{VENDOR}' quickshell)" == 'Fedora Project' ]] || die 'Vendor Quickshell inatteso.'
[[ "$(readlink -f "$(command -v quickshell)")" == /usr/bin/quickshell ]] || die 'Quickshell mascherato da eseguibile personale nel PATH.'
# RPM's Qt_6 / Qt_6.11_PRIVATE_API requirements do not encode every patch ABI.
# Stop before changing the desktop if an installed runtime is incompatible.
bash "$ROOT_DIR/bin/check-quickshell-runtime.sh" ||
  die "Runtime Quickshell/Qt incompatibile. Verificare environment e aggiornamenti Fedora; per allineare i pacchetti: sudo dnf --refresh --repo=fedora --repo=updates upgrade quickshell 'qt6-*'"
mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
install -m 0755 "$ROOT_DIR/bin/workstation-bar.sh" "$HOME/.local/bin/workstation-bar.sh"
install -m 0644 "$ROOT_DIR/templates/systemd/workstation-bar.service" "$HOME/.config/systemd/user/workstation-bar.service"
bash "$ROOT_DIR/bin/install-bluetui.sh"
python3 "$ROOT_DIR/bin/configure-sway-windows.py"
python3 "$ROOT_DIR/bin/configure-quickshell.py"
python3 "$ROOT_DIR/bin/configure-appearance.py"
install -D -m 0644 "$ROOT_DIR/templates/themes/dark/kitty.conf" "$HOME/.config/kitty/theme.conf"
systemctl --user daemon-reload
log 'Quickshell configurato. Effetto al prossimo login Sway; rollback: workstation-bar.sh waybar.'
