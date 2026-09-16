
## Convenzioni operative

1. Prima di cambiare il sistema desktop, leggere `config/versions.env`,
   `config/sources.env` e il modulo pertinente in `modules/`.
2. Rendere persistenti le modifiche nel repository del setup; evitare correzioni
   manuali non riproducibili sulla sola macchina.
3. Per software di sistema preferire, nell'ordine: repository Fedora ufficiali;
   repository RPM ufficiale del vendor con verifica GPG. Non usare COPR o script
   `curl | sh` senza consenso esplicito.
4. Centralizzare URL in `config/sources.env` e versioni/checksum in
   `config/versions.env`. Verificare gli artefatti statici prima dell'esecuzione e
   non disabilitare TLS o controlli GPG.
5. Il presente repository (`fedora-sway-setup`) ha come unico scope il sistema
   operativo base e l'ambiente desktop Wayland/Sway con Quickshell.
6. Strumenti di sviluppo opzionali (Java, Node, Python, Docker, VM, Tailscale,
   agenti CLI, app Flatpak) risiedono separatamente in `~/Progetti/personali/workstation-tools`.
7. Non eseguire l'intero setup come root. Usare `sudo` soltanto per pacchetti,
   servizi systemd e configurazioni realmente di sistema.
8. Conservare progetti e checkout nella gerarchia Progetti. Non archiviare
   credenziali, token o chiavi private nel repository o in questa directory.
9. Prima della consegna eseguire `./bin/test.sh`; per diagnosi rapida usare
   `./bin/doctor.sh`, e per la provenienza `./bin/provenance-audit.sh`.
10. Preservare file e modifiche dell'utente. I file dichiarati “gestiti” dal
    setup possono essere rigenerati; `LOCAL_NOTES.md` non deve essere sovrascritto.
11. Dopo ogni modifica strutturale al repository, aggiornare il contesto degli
    agenti nelle relative fonti del setup e rigenerare i file in `~/.agent` con
    `ROOT_DIR="$PWD" bash modules/05-agent-context.sh`.

## Architettura a due repository

- **fedora-sway-setup** (`~/Progetti/personali/fedora-workstation-setup`):
  Scope desktop: Sway, Quickshell, Greetd, Kitty, Zsh, dotfile GNU Stow, audio PipeWire,
  Bluetooth con BlueTUI, NetworkManager, portali XDG, tema Adwaita e sfondi.
- **workstation-tools** (`~/Progetti/personali/workstation-tools`):
  Scope strumenti: Profili `--dev`, `--infra`, `--agents`, `--apps`, `--media`.

## Note per componenti desktop specifici

- Sway: `sway-help` / Super+G mostra la guida condivisa. Quickshell è la barra e
  control center di default (con fallback Waybar). Non riattivare Mako quando
  Quickshell possiede le notifiche.
- Pairing Bluetooth: BlueTUI ufficiale in `workstation-system-tool bluetooth`;
  nuovi pairing nella TUI, connect/disconnect nel popup. PipeWire gestisce l'audio.
- Finestre normali (Kitty inclusa) tiled; solo app_id workstation-* riservati
  alle utility diventano floating. Preservare la policy e i bordi Sway.
- Quickshell desktop: Mod+d launcher, Mod+v clipboard solo RAM, Mod+Shift+v split
  verticale; Print/Shift+Print/Mod+Print catturano area/output/finestra.
  `workstation-shell` instrada azioni OSD native; `workstation-screenshot` salva
  e copia PNG. `workstation-lock --check` valida swaylock senza bloccare.
  Non leggere/loggare o versionare clipboard, né introdurre persistenza automatica.
- Quick Settings: QS sulla barra, istanza globale sul monitor cliccato; compone
  servizi esistenti, passa ai selector e non duplica backend. Toast Overlay, QS Top.
- Tema: `bin/configure-appearance.py` gestisce Adwaita + prefer-dark, Qt portal,
  icone/cursore Adwaita 24px, Adwaita Sans e Cascadia Mono NF. Niente CSS globale
  né Qt library path. Il chooser portal GTK è una utility floating dedicata.
- Dotfile utente: gestiti con GNU Stow tramite `bin/stow-dotfiles`. I file sotto
  `$HOME` sono symlink diretti ai file versionati in `dotfiles/`. Modifiche a
  runtime su file generati (`theme.conf`, `theme.css`, `fuzzel.ini`, ecc.) restano
  dinamiche, mentre le configurazioni stabili risiedono esclusivamente nel repository.
