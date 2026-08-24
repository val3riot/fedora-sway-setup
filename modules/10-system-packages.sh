#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

sudo -n true
if [[ "$PROFILE" != dev ]]; then
  sudo dnf upgrade --refresh -y
fi

base_packages=(
  git gitk git-lfs openssh-clients curl wget rsync
  unzip zip tar gzip bzip2 xz jq tree
  zsh bash-completion xdg-user-dirs
  cifs-utils
)

[[ "$PROFILE" != dev ]] && install_available_packages "${base_packages[@]}"

[[ "$PROFILE" != base ]] || exit 0

dev_packages=(
  git curl wget jq gnupg2 ripgrep fd-find fzf bat btop htop tmux ShellCheck
  gcc gcc-c++ make cmake ninja-build pkgconf-pkg-config
  openssl-devel libffi-devel zlib-ng-compat-devel
  gdb strace lsof
  pciutils usbutils iproute bind-utils traceroute nmap-ncat
)

install_available_packages "${dev_packages[@]}"
install_available_packages \
  texlive-scheme-medium openvpn openconnect \
  NetworkManager-openvpn NetworkManager-openconnect
