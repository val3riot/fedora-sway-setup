# Provenienza del software

Il setup usa, in ordine di preferenza, repository Fedora, repository del vendor e
release upstream ufficiali. URL, versioni e checksum sono definiti in
`config/sources.env`.

## Software Fedora

I seguenti componenti sono installati con DNF dai repository Fedora:

| Categoria | Software |
|---|---|
| Sistema e shell | Git, Zsh, OpenSSH, Kitty, tmux, Gitk |
| Plugin Zsh | `zsh-syntax-highlighting`, `zsh-autosuggestions` |
| Sviluppo | compilatori, strumenti di build, Python, TeX Live medium |
| Rete | `cifs-utils`, OpenVPN, OpenConnect |
| Desktop | Thunderbird, LibreOffice, Dash to Dock; Sway, Waybar, Fuzzel e componenti Wayland opzionali |
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
| Docker Desktop | 4.87.0 | `desktop.docker.com` | versione e SHA-256 RPM |
| DBeaver CE | 26.1.5 | `dbeaver.io` | versione e SHA-256 vendor |
| Bruno | release corrente | `github.com/usebruno/bruno` | digest SHA-256 della release |
| JetBrains Toolbox | release corrente | API JetBrains | checksum SHA-256 vendor |

Codex, Claude Code e Copilot CLI sono installati solo con
`INSTALL_AGENTS=true`. Durante i bootstrap, il setup rimuove dall'ambiente
`GITHUB_TOKEN`, `GH_TOKEN`, `OPENAI_API_KEY` e `ANTHROPIC_API_KEY`.

## Repository vendor

| Software | Repository | Verifica |
|---|---|---|
| Docker Engine CE, Buildx, Compose V2 | Docker Fedora | chiave GPG e fingerprint Docker |
| Visual Studio Code | Microsoft RPM | chiave GPG Microsoft |

Docker Engine viene configurato in modalità rootless. Docker Desktop è installato
dal proprio RPM verificato.

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

## Quickshell opzionale — verifica 2026-09-06

Fonti ufficiali consultate: [installazione upstream](https://quickshell.org/docs/v0.2.1/guide/install-setup/)
e [pacchetto Fedora 44](https://packages.fedoraproject.org/pkgs/quickshell/quickshell/fedora-44.html).
Gli URL sono centralizzati per i controlli in `config/sources.env`.
La guida upstream cita ancora Rawhide e propone anche il COPR
`errornointernet/quickshell`. Quest'ultimo è **upstream-recommended, non Fedora
official**. Il registro Fedora e `dnf --repo=fedora --repo=updates repoquery`
confermano però il pacchetto nei repository ufficiali Fedora 44: viene preferito
questo e non viene aggiunto alcun COPR, fork o installer esterno.

Pacchetto rilevato in updates: `quickshell-0.2.1^git20260209.dacfa9d-5.fc44.x86_64`;
eseguibile: `quickshell 0.2.1`, revisione
`dacfa9de829ac7cb173825f593236bf2c21f637e`, distributore Fedora Project.
Non si blocca una release RPM. Quickshell usa API private Qt: le dipendenze
RPM non garantiscono da sole la compatibilità tra patch release; il modulo
verifica anche il loader con `LD_BIND_NOW=1 quickshell --version`. La transazione del modulo 76
limita **anche le dipendenze** a `fedora` e `updates`. Nessuna deroga TLS/GPG.
Pacchetti aggiuntivi: `python3-gobject`, `NetworkManager-libnm`, anch'essi Fedora.
Vendor inatteso o eseguibile che maschera `/usr/bin/quickshell` causano arresto;
audit e doctor verificano ownership, vendor e integrità `rpm -V` quando selezionato.

Gli adapter distribuiti dal repository leggono esclusivamente dati kernel locali,
Sway IPC e NetworkManager D-Bus. Nessun endpoint remoto, password, Wi-Fi/VPN control
o polling di comandi esterni. Audio tramite oggetti nativi PipeWire con tracking.
Il solo helper power esegue comandi fissi dopo un click esplicito sul menu; la
modalità `WORKSTATION_QUICKSHELL_TEST=1` impedisce ogni azione, anche chiamando
l'helper direttamente. Nessun servizio notifiche o policykit Quickshell attivato.

Validazione finale sulla workstation: Quickshell RPM ufficiale installato,
Qt allineato a 6.11.2 tramite DNF (transazione 22), integrità RPM e librerie
caricate da /usr/lib64 verificate. Standalone e servizio caricano la
configurazione reale; il fallback Waybar è stato provato e poi Quickshell
ripristinato. Doctor Quickshell e suite repository passano. Dettagli del
mismatch Qt 6.11.1 e delle verifiche in
`docs/quickshell-qt-abi-2026-09-06.md`.
