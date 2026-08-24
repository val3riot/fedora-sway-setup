#!/usr/bin/env bash
set -Eeuo pipefail
source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"

conda_dir="$TOOLS_DIR/miniconda3"
if [[ ! -x "$conda_dir/bin/conda" ]]; then
  installer="$TOOLS_DIR/tmp/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh"
  download_verified "$MINICONDA_INSTALLER_URL" "$installer" "$MINICONDA_INSTALLER_SHA256"
  bash "$installer" -b -p "$conda_dir"
fi
"$conda_dir/bin/conda" config --set auto_activate_base false
