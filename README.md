# Fedora Sway Setup

Bootstrap idempotente e focalizzato per configurare un ambiente desktop Wayland moderno e reattivo su **Fedora 44** con **Sway**, **Quickshell** e gestione dotfile basata su **GNU Stow**.

> **Scope delimitato:** Questo repository gestisce esclusivamente il sistema operativo base e l'ambiente desktop.
> Strumenti di sviluppo (Java, Node, Python, Docker, VM), agenti AI e applicazioni personali sono gestiti nel repository modulare separato:
> [**workstation-tools**](../workstation-tools/README.md) (`~/Progetti/personali/workstation-tools`).

---

## 1. Caratteristiche Principali

- **Window Manager**: [Sway](https://swaywm.org/) con configurazione tiling logica, bordi puliti e supporto multi-monitor.
- **Display Manager**: [Greetd](https://man.sr.ht/~kennylevinsen/greetd/) per il login grafico Wayland, con sfondo sincronizzato con la sessione utente.
- **Desktop Shell**: [Quickshell](https://quickshell.org/) come barra superiore reattiva, server di notifiche nativo Freedesktop, Quick Settings globale, selettori rapidi Wi-Fi (via `libnm`) e Bluetooth (con integrazione TUI ufficiale BlueTUI in Kitty floating).
- **Fallback Automatico**: Servizio di supervisione `workstation-bar.service` con ripiegamento trasparente su [Waybar](https://github.com/Alexays/Waybar) e [Mako](https://github.com/emersion/mako) in caso di anomalia di Quickshell.
- **Terminale & Shell**: [Kitty](https://sw.kovidgoyal.net/kitty/) con rendering GPU, Zsh con plugin ufficiali Fedora, tema personalizzato e prompt reattivo [Starship](https://starship.rs/).
- **Dotfile tramite GNU Stow**: I file in `$HOME` (`~/.config/...`, `~/.zshrc`) sono symlink diretti ai file versionati in `dotfiles/`. Le modifiche locali aggiornano istantaneamente il repository Git.
- **Tema & Aspetto**: [Adwaita Dark](https://gnome.pages.gitlab.gnome.org/libadwaita/) coerente tra applicazioni GTK (portal, 3.0, 4.0), Qt (portal) e Sway, icone/cursori Adwaita a 24px, font *Cascadia Code* e *Adwaita Sans*.
- **Diagnostica Desktop Rapida**: `bin/doctor.sh` deterministico e completamente offline, con esecuzione in meno di **2 secondi**.

---

## 2. Installazione e Utilizzo

Eseguire lo script come utente normale; `sudo` viene richiesto una sola volta per le operazioni di sistema.

```bash
# Installazione predefinita del desktop completo
./install.sh

# Mostra i moduli pianificati senza apportare modifiche
./install.sh --dry-run

# Configura Waybar come barra principale invece di Quickshell
./install.sh --no-quickshell

# Esegue la diagnostica al termine dell'installazione
./install.sh --doctor

# Seleziona o cambia lo sfondo interattivamente
./install.sh --set-wallpaper

# Guida alle opzioni CLI
./install.sh --help
```

---

## 3. Gestione Dotfile (GNU Stow)

I file di configurazione utente sono organizzati in pacchetti modulari nella cartella `dotfiles/`:

```text
repository Git (dotfiles/<pacchetto>/...)
    ↓
GNU Stow (bin/stow-dotfiles)
    ↓
~/.config/...
~/.zshrc
~/.local/...
```

### Comandi Disponibili

```bash
# Applica tutti i pacchetti dotfile e crea o aggiorna i symlink
./bin/stow-dotfiles apply

# Applica solo pacchetti specifici
./bin/stow-dotfiles apply shell kitty sway

# Verifica l'integrità dei symlink (modalità sola lettura)
./bin/stow-dotfiles check

# Rimuove i symlink di un pacchetto dal target
./bin/stow-dotfiles remove kitty
```

### Pacchetti Gestiti in `dotfiles/`

- `shell`: `~/.zshrc`, `~/.config/starship.toml`, `~/.config/workstation-setup/zsh-theme.zsh`
- `kitty`: `~/.config/kitty/kitty.conf`
- `sway`: `~/.config/sway/config`, `~/.config/sway/config.d/`, autostart e regole finestre
- `swaylock`: `~/.config/swaylock/config`
- `waybar`: `~/.config/waybar/config`, `~/.config/waybar/style.css`
- `quickshell`: `~/.config/quickshell/workstation/...`
- `systemd-user`: `~/.config/systemd/user/workstation-bar.service`
- `desktop-theme`: `~/.config/gtk-3.0/settings.ini`, `gtk-4.0/settings.ini`, configurazione font
- `scripts`: script helper utente in `~/.local/bin/` (`sway-help`, `workstation-shell`, `workstation-screenshot`, ecc.)

> **Nota:** I file generati o alterati dinamicamente a runtime (`theme.conf`, `theme.css`, `fuzzel.ini`, `90-bar.conf`, `95-notifications.conf`) restano gestiti dal selettore del tema in `$HOME/.config/` senza sporcare il tracciamento Git.

---

## 4. Scorciatoie Principali (Sway)

Per l'elenco interattivo e ricercabile completo, premere **`Super+G`** (o eseguire `sway-help` nel terminale).

| Scorciatoia | Azione |
|---|---|
| `Super + Invio` | Apre un nuovo terminale Kitty |
| `Super + D` | Launcher applicazioni (Fuzzel) |
| `Super + G` | Guida comandi e scorciatoie (`sway-help`) |
| `Super + V` | Selettore clipboard volatile (solo RAM) |
| `Super + Shift + V` | Imposta il layout di split verticale |
| `Super + Shift + Q` | Chiude la finestra corrente |
| `Super + Shift + C` | Ricarica la configurazione di Sway |
| `Print` | Cattura uno screenshot di un'area selezionata |
| `Shift + Print` | Cattura uno screenshot dello schermo intero |
| `Super + Print` | Cattura uno screenshot della finestra attiva |
| `Super + Shift + E` | Mostra il menu di uscita/spegnimento |

---

## 5. Strumenti di Sviluppo e Strumenti Opzionali

Se sulla workstation servono container Docker, macchine virtuali libvirt/KVM, toolchain Java/Node/Python, IDE come VS Code o agenti AI come Codex, fare riferimento a **`workstation-tools`**:

```bash
cd ~/Progetti/personali/workstation-tools
./install.sh --help

# Esempi:
./install.sh --dev           # SDKMAN, Node, Miniconda, VS Code, DBeaver, Bruno
./install.sh --infra         # Docker rootless, KVM, Tailscale, VPN
./install.sh --agents        # Codex, Claude Code, Copilot CLI
```

---

## 6. Verifica e Test del Repository

Il repository include una suite di verifica completa, veloce e non invasiva:

```bash
# Diagnostica rapida desktop (< 2s, offline, deterministica)
./bin/doctor.sh

# Esecuzione della suite di test completa (sintassi, ShellCheck, integrazione)
./bin/test.sh

# Controllo della provenienza dei pacchetti e assenza di COPR
./bin/provenance-audit.sh

# Verifica centralizzazione URL ed endpoint esterni
./bin/audit-urls.sh [--online]
```
