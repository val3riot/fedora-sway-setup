# Provenienza del software

Il setup usa, in ordine di preferenza, repository Fedora, repository del vendor e
release upstream ufficiali. Gli URL sono definiti in `config/sources.env`; versioni
e checksum sono definiti in `config/versions.env`.

## Software Fedora

I seguenti componenti sono installati con DNF dai repository Fedora:

| Categoria | Software |
|---|---|
| Sistema e shell | Git, Zsh, OpenSSH, Kitty, tmux, Gitk |
| Plugin Zsh | `zsh-syntax-highlighting`, `zsh-autosuggestions` |
| Sviluppo | compilatori, strumenti di build, Python, TeX Live medium |
| Rete | `cifs-utils`, OpenVPN, OpenConnect |
| Desktop | Thunderbird, LibreOffice, Dash to Dock |
| Virtualizzazione | KVM/QEMU, libvirt, virt-manager, Vagrant |
| Alimentazione | TuneD e supporto `intel_pstate` |

Gli RPM Fedora sono verificati da DNF con le chiavi configurate dal sistema.

## Release e installer verificati

| Software | Versione | Fonte | Verifica |
|---|---:|---|---|
| Oh My Zsh | commit `d42209f2afa8ec3e6971e5b4695ff27f9d5670d2` | `ohmyzsh/ohmyzsh` | commit e SHA-256 installer |
| Starship | 1.26.0 | release GitHub `starship/starship` | SHA-256 archivio |
| NVM | 0.40.6 | `nvm-sh/nvm` | versione e SHA-256 installer |
| Miniconda | py314_26.5.3-2 | Anaconda | versione e SHA-256 installer |
| Codex | 0.149.0 | `releases.openai.com` | versione e SHA-256 bootstrap; checksum release verificato dall'installer |
| Claude Code | 2.1.239 | `claude.ai` | versione e SHA-256 bootstrap; checksum release verificato dall'installer |
| Copilot CLI | 1.0.80 | `gh.io` e release `github/copilot-cli` | versione e SHA-256 bootstrap; checksum release verificato dall'installer |
| DBeaver CE | 26.1.5 | `dbeaver.io` | versione e SHA-256 vendor |
| Bruno | release corrente | `github.com/usebruno/bruno` | digest SHA-256 della release |
| JetBrains Toolbox | release corrente | API JetBrains | checksum SHA-256 vendor |

Codex, Claude Code e Copilot CLI sono installati con `--agent` oppure `--all`.
Durante i bootstrap, il setup rimuove dall'ambiente
`GITHUB_TOKEN`, `GH_TOKEN`, `OPENAI_API_KEY` e `ANTHROPIC_API_KEY`.

## Repository vendor

| Software | Repository | Verifica |
|---|---|---|
| Docker Engine CE, Buildx, Compose V2 | Docker Fedora | chiave GPG e fingerprint Docker |
| Visual Studio Code | Microsoft RPM | chiave GPG Microsoft |

Docker Engine viene sempre configurato in modalità rootless dal profilo `--dev`.

## Flatpak

Discord e Obsidian sono installati per il singolo utente da Flathub. Flathub è un
repository comunitario e viene dichiarato esplicitamente come fonte di terza parte.

## Controlli

```bash
./bin/test.sh
./bin/provenance-audit.sh
./bin/audit-urls.sh --online
./bin/check-secrets.sh
```

`bin/test.sh` controlla sintassi, ShellCheck, test funzionali, policy delle fonti,
segreti tracciati e disabilitazioni TLS/GPG. `bin/provenance-audit.sh` verifica
proprietario RPM, path degli eseguibili, repository configurati e duplicati nel
`PATH`.
