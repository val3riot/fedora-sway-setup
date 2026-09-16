#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

sudo -n true
sudo timedatectl set-timezone Europe/Rome
sudo timedatectl set-ntp true

sudo dnf upgrade --refresh -y

desktop_base_packages=(
  git openssh-clients curl wget rsync
  unzip zip tar gzip bzip2 xz jq stow
  zsh bash-completion xdg-user-dirs
)

install_available_packages "${desktop_base_packages[@]}"
