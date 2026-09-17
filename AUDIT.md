# Provenienza del software — Fedora Sway Setup

Questo repository gestisce esclusivamente l'ambiente desktop Wayland basato su Sway per Fedora 44.

---

## 1. Software Fedora Official (RPM)

I seguenti componenti sono installati tramite DNF dai repository ufficiali Fedora (`fedora`, `updates`) e verificati tramite le chiavi GPG di sistema del Fedora Project:

| Categoria | Pacchetti RPM |
|---|---|
| **Sistema e shell** | `git-core`, `zsh`, `zsh-syntax-highlighting`, `zsh-autosuggestions`, `openssh-clients` |
| **Terminale** | `kitty` |
| **Window Manager & Compositor** | `sway`, `sway-config-fedora`, `swaylock`, `swayidle` |
| **Barre e selettori** | `quickshell` |
| **Cattura e clipboard** | `grim`, `slurp`, `wl-clipboard` |
| **Audio e periferiche** | `pipewire`, `pipewire-pulseaudio`, `wireplumber`, `bluez`, `NetworkManager`, `NetworkManager-tui` |
| **Display Manager** | `greetd` |
| **Gestione Energetica** | `tuned`, `tuned-ppd` |
| **Librerie e bridge** | `python3-gobject`, `NetworkManager-libnm`, `qt6-qtdeclarative`, `qt6-qtquick3d` |

---

## 2. Release Upstream Verificate (Digest Statico)

Per i componenti non distribuiti come RPM di sistema, gli artefatti vengono scaricati da release upstream ufficiali e convalidati tramite hash SHA-256 fisso definito in `config/versions.env`:

| Software | Versione / Commit | Fonte Upstream | Verifica |
|---|---|---|---|
| **Starship** | `1.26.0` | GitHub `starship/starship` release x86_64 | SHA-256 archivio verificato |
| **BlueTUI** | `0.8.1` | GitHub `pythops/bluetui` release x86_64 | SHA-256 binario verificato |
| **Oh My Zsh** | Commit `d42209f2afa8ec3e6971e5b4695ff27f9d5670d2` | GitHub `ohmyzsh/ohmyzsh` | Commit fisso + SHA-256 installer |

Nessun download viene eseguito senza validazione SHA-256 preventiva. Non sono ammesse deroghe alle verifiche crittografiche o esecuzioni non verificate.

---

## 3. Quickshell: Dettaglio Provenienza e Sicurezza

- **Pacchetto**: `quickshell-0.2.1^git20260209.dacfa9d-5.fc44.x86_64`
- **Distributore**: Fedora Project (nessun repository COPR di terze parti come `errornointernet/quickshell` viene abilitato).
- **Integrità binario**: validata con `rpm -V quickshell`.
- **Compatibilità ABI**: il modulo di setup e il doctor verificano il loader dinamico con `LD_BIND_NOW=1 quickshell --version`.
- **Supervisione**: gestito da `systemd --user` (`workstation-bar.service`).

---

## 4. Politica Repository di Terze Parti e COPR

- **COPR**: Nessun repository COPR è abilitato o richiesto.
- **Repository Vendor esterni**: Nessun repository RPM di terze parti (Microsoft, Docker, ecc.) è configurato in questo repository.
- **Flatpak**: Nessuna applicazione Flatpak è installata dallo script di setup desktop.

---

## 5. Script di Controllo e Verifica

```bash
# Esegue l'intera suite di test del repository
./bin/test.sh

# Diagnostica rapida dello stato desktop (< 2 secondi)
./bin/doctor.sh

# Controllo locale della provenienza di binari e pacchetti RPM
./bin/provenance-audit.sh

# Convalida classificazione e raggiungibilità degli endpoint URL
./bin/audit-urls.sh [--online]

# Controllo assenza token, chiavi o segreti tracciati
./bin/check-secrets.sh
```
