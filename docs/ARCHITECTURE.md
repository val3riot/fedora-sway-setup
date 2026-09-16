# Architettura di Fedora Sway Setup

Questo repository (`fedora-sway-setup`) ha un unico scopo ben delimitato: **fornire una workstation Fedora completa basata su Sway, Quickshell e GNU Stow**.

Non gestisce container, macchine virtuali, SDK di sviluppo (Java, Node, Python), agenti AI o applicazioni desktop di terze parti: questi componenti risiedono nel repository gemello **`workstation-tools`** (`~/Progetti/personali/workstation-tools`).

---

## 1. Modello Architetturale

```
                    ┌───────────────────────────────┐
                    │       Fedora Linux 44         │
                    │      (DNF5 / systemd)         │
                    └───────────────┬───────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │    Greetd (Login Greeter)     │
                    └───────────────┬───────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │        Sway (Wayland)         │
                    │   Tiling WM + XDG Desktop     │
                    └───────┬───────────────┬───────┘
                            │               │
            ┌───────────────┘               └───────────────┐
            ▼                                               ▼
┌───────────────────────────────┐               ┌───────────────────────────────┐
│     Quickshell Desktop        │               │       Shell & Terminal        │
│ • Barra di stato              │               │ • Kitty Terminal              │
│ • Quick Settings              │               │ • Zsh + Oh My Zsh             │
│ • Server Notifiche nativo     │               │ • Starship Prompt             │
│ • Audio, Wi-Fi, Bluetooth     │               └───────────────────────────────┘
│ • Fallback automatico Waybar  │
└───────────────────────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │     GNU Stow Dotfiles         │
                    │   Symlink diretti dal repo    │
                    │   verso $HOME (~/.config/...) │
                    └───────────────────────────────┘
```

---

## 2. Divisione dei Due Repository

| Ambito | Repository: `fedora-sway-setup` | Repository: `workstation-tools` |
|---|---|---|
| **Missione** | "Rendo Fedora il mio desktop Sway completo" | "Installo strumenti opzionali sopra la workstation" |
| **Piattaforma** | Fedora 44 x86_64, Wayland, Sway, Greetd | Agnostico rispetto al DE (gira su Sway, GNOME o headless) |
| **Componenti** | Sway, Quickshell, Waybar, Fuzzel, Swaylock, Kitty, Zsh, Starship, GNU Stow, BlueTUI, PipeWire, BlueZ, NetworkManager, portali XDG, tema Adwaita | Docker (rootless & desktop), KVM/QEMU, virt-manager, Vagrant, Tailscale, VPN, SDKMAN (Java/Maven/Gradle), NVM/Node, Miniconda, VS Code, DBeaver, Bruno, JetBrains, Codex, Claude Code, Copilot CLI, Flatpak (Discord, Obsidian), Cliamp |
| **Esecuzione** | `./install.sh` (installa il desktop completo) | `./install.sh` (stampa help; richiede flag `--dev`, `--infra`, ecc.) |
| **Doctor** | Rapido (< 2s), deterministico, offline, verifica solo lo stato del desktop | Ispeziona o valida i singoli strumenti configurati |

---

## 3. Gestione Dotfile con GNU Stow

Tutti i file di configurazione stabili risiedono in `dotfiles/<pacchetto>/` e vengono proiettati in `$HOME` tramite symlink gestiti da `bin/stow-dotfiles`.

### Pacchetti Dotfile

- `shell`: `~/.zshrc`, `~/.config/starship.toml`, `~/.config/workstation-setup/zsh-theme.zsh`
- `kitty`: `~/.config/kitty/kitty.conf`
- `sway`: `~/.config/sway/config`, `~/.config/sway/config.d/`, shortcut, autostart
- `swaylock`: `~/.config/swaylock/config`
- `waybar`: `~/.config/waybar/config`, `~/.config/waybar/style.css` (fallback di Quickshell)
- `quickshell`: `~/.config/quickshell/workstation/...` (QML shell, bar, quick settings, popups)
- `systemd-user`: `~/.config/systemd/user/workstation-bar.service`
- `desktop-theme`: `~/.config/gtk-3.0/settings.ini`, `gtk-4.0/settings.ini`, fontconfig
- `scripts`: script helper in `~/.local/bin/` (`workstation-shell`, `sway-help`, `workstation-screenshot`, ecc.)

### Modifiche a Runtime

I file modificati dinamicamente dal tema (`theme.conf`, `theme.css`, `fuzzel.ini`, `90-bar.conf`, `95-notifications.conf`) vengono gestiti da `bin/configure-appearance.py` e posizionati in `$HOME/.config/` senza sovrascrivere o sporcare i file versionati da Stow.

---

## 4. Sottosistemi Desktop

### Gestore Finestre e Display (Sway)
- Tiling automatico per applicazioni standard (Kitty, editor, browser).
- Finestre floating compatte con app_id `workstation-*` per dialoghi di sistema, selettori e utilità.
- Greetd come display manager con sessione Sway e sfondo sincronizzato.
- `swaylock` per blocco schermo sicuro con verifica preventiva senza freeze (`workstation-lock --check`).
- `sway-help` (`Super+G`) come guida comandi interattiva e ricercabile.

### Desktop Shell (Quickshell con Fallback Waybar)
- Barra superiore minimale e reattiva scritta in Qt/QML.
- Server notifiche D-Bus integrato conforme alla specifica Freedesktop.
- Quick Settings globale a comparsa sul monitor attivo.
- Selettore Wi-Fi nativo basato su `NetworkManager-libnm` (nessun subshell o parsing di `nmcli`).
- Selettore Bluetooth nativo con integrazione TUI ufficiale BlueTUI in terminale floating per pairing e autenticazione PIN.
- Audio nativo tramite oggetti PipeWire.
- Servizio di supervisione `workstation-bar.service`: se Quickshell incontra anomalie o incompatibilità ABI, esegue il fallback automatico su Waybar.

### Diagnostica Rapida (Doctor)
- `bin/doctor.sh` esegue solo verifiche desktop locali:
  1. Pacchetti RPM base e coerenza versioni.
  2. Integrità symlink GNU Stow.
  3. Servizi systemd utente e sistema (PipeWire, WirePlumber, NetworkManager, Greetd, bluetooth).
  4. Configurazione Sway, Quickshell e asset grafici (sfondo, icone, font).
  5. Tempo di esecuzione rigorosamente **inferiore a 2 secondi**.
