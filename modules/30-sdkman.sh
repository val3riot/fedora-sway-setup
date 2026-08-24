#!/usr/bin/env bash
set -Eeo pipefail

source "$ROOT_DIR/lib/common.sh"
load_config "$ROOT_DIR"


export SDKMAN_DIR="$TOOLS_DIR/sdkman"

install_sdkman() {
  local installer="$TOOLS_DIR/tmp/install-sdkman.sh"
  local attempt
  local max_attempts=4

  if [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
    return 0
  fi

  for ((attempt=1; attempt<=max_attempts; attempt++)); do
    log "Installazione SDKMAN (tentativo $attempt/$max_attempts)"

    # Un'installazione interrotta lascia una directory parziale. SDKMAN richiede
    # che la directory custom non esista prima di una nuova installazione.
    rm -rf "$SDKMAN_DIR"
    rm -f "$installer"

    if ! download "$SDKMAN_INSTALL_URL" "$installer"; then
      warn "Download installer SDKMAN fallito (tentativo $attempt/$max_attempts)."
    elif bash "$installer" && [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
      return 0
    else
      warn "Installer SDKMAN interrotto (tentativo $attempt/$max_attempts). Riprovo da zero."
    fi

    sleep $((attempt * 3))
  done

  die "Installazione SDKMAN fallita dopo $max_attempts tentativi. Verifica la rete e rilancia il setup."
}

install_sdkman

# SDKMAN può chiedere conferma quando installa o cambia la versione predefinita.
# Il bootstrap deve poter proseguire senza letture implicite dallo standard input.
sdkman_config="$SDKMAN_DIR/etc/config"
if grep -q '^sdkman_auto_answer=' "$sdkman_config"; then
  sed -i 's/^sdkman_auto_answer=.*/sdkman_auto_answer=true/' "$sdkman_config"
else
  printf '%s\n' 'sdkman_auto_answer=true' >> "$sdkman_config"
fi

# SDKMAN utilizza parametri posizionali opzionali come $2.
# Non è compatibile con `set -u`.
set +u

# shellcheck disable=SC1091
source "$SDKMAN_DIR/bin/sdkman-init.sh"

for candidate in $SDKMAN_JAVA_CANDIDATES; do
  if [[ "$candidate" == "java" || "$candidate" == "stable" ]]; then
    sdk install java || warn "Installazione della Java stable tramite SDKMAN fallita."
  else
    sdk install java "$candidate" ||
      warn "Installazione Java SDKMAN fallita per: $candidate"
  fi
done

# Rende predefinita la prima Java configurata, se installata correttamente.
first_java_candidate="${SDKMAN_JAVA_CANDIDATES%% *}"
if [[ "$first_java_candidate" != "java" && "$first_java_candidate" != "stable" ]]; then
  sdk default java "$first_java_candidate" || warn "Impossibile impostare Java $first_java_candidate come default."
fi

sdk install maven || warn "Installazione Maven tramite SDKMAN fallita."
sdk install gradle || warn "Installazione Gradle tramite SDKMAN fallita."
