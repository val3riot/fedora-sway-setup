#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

if ! rpm -q code >/dev/null 2>&1; then
  sudo rpm --import "$VSCODE_GPG_KEY_URL"
  sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<REPO
[code]
name=Visual Studio Code
baseurl=$VSCODE_REPO_BASEURL
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=$VSCODE_GPG_KEY_URL
REPO
  sudo dnf install -y code
fi
