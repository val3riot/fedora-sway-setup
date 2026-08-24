# Fedora 44 Workstation Setup

Bootstrap idempotente e indipendente dal desktop environment per Fedora 44.
Eseguire lo script come utente normale; `sudo` viene richiesto una sola volta.

## Profili software

I profili software disponibili sono:

```bash
./install.sh --base
./install.sh --dev
./install.sh --all
```

- `--base`: directory, shell, Git, Tailscale, strumenti di sistema e gestione energetica.
- `--dev`: toolchain, Kitty, tmux, SDKMAN, Node, Miniconda, VS Code,
  virtualizzazione e Docker Engine rootless con avvio automatico.
- `--all`: unione di base e dev, applicazioni desktop e agenti CLI.

`--dev` non applica configurazioni specifiche per GNOME o Sway.

## Componenti combinabili

```bash
./install.sh --sway
./install.sh --gnome
./install.sh --base --agent --sway
./install.sh --extra
./install.sh --base --extra
./install.sh --dev --gnome
./install.sh --all --sway
```

- `--agent` aggiunge Codex, Claude Code e Copilot CLI a `--base` o `--dev`.
- `--extra` installa software ricreativo e non essenziale, attualmente Cliamp,
  il player musicale TUI con file locali, stream e radio Internet. È opt-in e
  non viene incluso neppure da `--all`. Con Sway aggiunge una voce al launcher
  e un controllo Waybar: clic sinistro per avviare o mostrare/nascondere lo
  scratchpad, clic destro per chiudere il player.
- `--sway` installa o aggiorna Sway, Kitty e le relative configurazioni; non
  richiede un profilo software.
- `--gnome` installa o aggiorna soltanto GNOME e la configurazione GNOME; non
  richiede un profilo software.

`--sway` e `--gnome` sono mutuamente esclusivi. `--all` non sceglie un desktop:
per applicarne la configurazione bisogna indicarlo esplicitamente.

Le applicazioni desktop incluse in `--all` sono DBeaver, Bruno, JetBrains
Toolbox, Thunderbird, LibreOffice, Discord e Obsidian.

## Sway e Waybar

La configurazione Sway usa il tiling per le applicazioni principali e finestre
flottanti compatte per autenticazione PolicyKit, connessioni di rete e controllo
audio. Le finestre floating si spostano con `Super` + trascinamento sinistro e si
ridimensionano con `Super` + trascinamento destro.

`Super+D` apre il menu applicazioni e, se è già visibile, lo chiude. La finestra
delle scorciatoie adatta font, larghezza e numero di righe allo schermo attivo:
rimane sempre sotto Waybar e dentro i bordi del desktop.

Waybar mostra icona e percentuale della batteria. Un clic sulla batteria apre il
selettore dei profili energetici:

- `Dev 60%`: profilo bilanciato, turbo attivo, CPU limitata al 60%;
- `Risparmio`: profilo power-saver, turbo attivo, limite predefinito al 45%;
- `Prestazioni`: profilo performance, CPU al 100%.

Il selettore resta aperto se il puntatore cambia finestra; si chiude con `Esc` o
dopo la scelta. L'autorizzazione amministrativa avviene tramite PolicyKit.
Anche il menu di sistema aperto dall'icona di spegnimento resta visibile quando
il focus lascia Waybar e si chiude con `Esc` o dopo aver scelto un'azione.

## Configurazione

Gli endpoint sono in `config/sources.env`; versioni e checksum associati sono in
`config/versions.env` e possono essere modificati direttamente. Quando si cambia
una versione va aggiornato anche il relativo checksum. La CLI è l'unica fonte di
verità per la selezione dei componenti.

Un modulo fallito, incluso un download con checksum non valido, viene interrotto
senza eseguire il file non verificato; gli altri moduli continuano. Al termine il
setup stampa il report `SUCCESS/FAILED` e restituisce codice 1 se ci sono errori.

## Creazione delle VM

Dopo `./install.sh --dev`, ogni guest può essere creato da una ISO locale senza
dipendere da nomi o distribuzioni predefiniti:

```bash
./bin/create-vms.sh laboratorio "$HOME/Tools/ISO/sistema.iso"
./bin/create-vms.sh test-uefi "$HOME/Tools/ISO/sistema.iso" --memory 8192 --vcpus 4 --disk-size 80 --uefi --tpm
```

Sono disponibili anche `--osinfo ID` per indicare esplicitamente il sistema
operativo e `--help` per l'elenco completo delle opzioni. Le VM esistenti con lo
stesso nome non vengono modificate.

## Verifica e utility

```bash
./bin/test.sh
./bin/doctor.sh
./bin/provenance-audit.sh
./bin/audit-urls.sh --online
```

Altre utility:

```bash
./bin/add-git-identity.sh
./bin/create-vms.sh NOME ISO
./bin/set-wallpaper.sh
docker-runtime status
laptop-power-mode status
laptop-power-mode dev 60
laptop-power-mode quiet
laptop-power-mode full
```
