#!/usr/bin/env bash
set -Eeuo pipefail

require_value() {
  local label=$1 value=$2
  [[ -n "$value" ]] || { printf 'Valore obbligatorio: %s\n' "$label" >&2; exit 1; }
}

read -r -p 'Nome breve del profilo (es. personal, azienda-github, cliente-gitlab): ' profile
[[ "$profile" =~ ^[a-zA-Z0-9._-]+$ ]] || { echo 'Nome profilo non valido.' >&2; exit 1; }

read -r -p 'Nome Git visualizzato: ' git_name
read -r -p 'Email Git: ' git_email
read -r -p 'Directory assoluta dei repository per questo profilo: ' repo_dir
read -r -p 'Host Git reale (es. github.com, gitlab.com, git.azienda.it): ' real_host
read -r -p 'Alias SSH univoco (es. github-azienda): ' host_alias
read -r -p 'Utente SSH [git]: ' ssh_user
ssh_user="${ssh_user:-git}"

require_value 'nome Git' "$git_name"
require_value 'email Git' "$git_email"
require_value 'directory repository' "$repo_dir"
require_value 'host Git reale' "$real_host"
require_value 'alias SSH' "$host_alias"

[[ "$host_alias" =~ ^[a-zA-Z0-9._-]+$ ]] || { echo 'Alias SSH non valido.' >&2; exit 1; }
[[ "$real_host" != *[[:space:]]* ]] || { echo 'Host Git non valido.' >&2; exit 1; }

repo_dir="${repo_dir/#\~/$HOME}"
[[ "$repo_dir" == /* ]] || { echo 'La directory dei repository deve essere assoluta.' >&2; exit 1; }

mkdir -p "$repo_dir" "$HOME/.config/git/identities" "$HOME/.ssh"
repo_dir="$(realpath -m "$repo_dir")/"
identity_file="$HOME/.config/git/identities/$profile.gitconfig"
key_file="$HOME/.ssh/id_ed25519_$profile"

cat > "$identity_file" <<CFG
[user]
    name = $git_name
    email = $git_email
CFG
chmod 600 "$identity_file"

git config --global --replace-all "includeIf.gitdir:$repo_dir.path" "$identity_file"

if [[ ! -f "$key_file" ]]; then
  ssh-keygen -t ed25519 -C "$git_email" -f "$key_file"
fi

touch "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config"

if awk -v wanted="$host_alias" '
  $1 == "Host" {
    for (i = 2; i <= NF; i++) if ($i == wanted) found=1
  }
  END { exit(found ? 0 : 1) }
' "$HOME/.ssh/config"; then
  printf 'Alias SSH già presente, configurazione non modificata: %s\n' "$host_alias"
else
  cat >> "$HOME/.ssh/config" <<CFG

Host $host_alias
    HostName $real_host
    User $ssh_user
    IdentityFile $key_file
    IdentitiesOnly yes
CFG
fi

printf '\nProfilo creato. Usa questo alias nei remote:\n'
printf '  git clone %s@%s:organizzazione/repository.git\n\n' "$ssh_user" "$host_alias"
printf 'Gli URL con l host reale non usano automaticamente questa chiave.\n'
printf 'Per repository esistenti: git remote set-url origin %s@%s:organizzazione/repository.git\n\n' "$ssh_user" "$host_alias"
printf 'Chiave pubblica da registrare sul servizio Git:\n'
cat "$key_file.pub"
