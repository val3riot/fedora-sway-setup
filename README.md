# Fedora 44 Workstation Setup

Bootstrap idempotente e indipendente dal desktop environment per Fedora 44.
Eseguire lo script come utente normale; `sudo` viene richiesto una sola volta.

## Profili software

È obbligatorio specificare esattamente un profilo:

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
./install.sh --base --agent --sway
./install.sh --dev --gnome
./install.sh --all --sway
```

- `--agent` aggiunge Codex, Claude Code e Copilot CLI a `--base` o `--dev`.
- `--sway` installa Sway e applica soltanto la configurazione Sway.
- `--gnome` installa GNOME e applica soltanto la configurazione GNOME.

`--sway` e `--gnome` sono mutuamente esclusivi. `--all` non sceglie un desktop:
per applicarne la configurazione bisogna indicarlo esplicitamente.

Le applicazioni desktop incluse in `--all` sono DBeaver, Bruno, JetBrains
Toolbox, Thunderbird, LibreOffice, Discord e Obsidian.

## Configurazione

Gli endpoint sono in `config/sources.env`; versioni e checksum associati sono in
`config/versions.env` e possono essere modificati direttamente. Quando si cambia
una versione va aggiornato anche il relativo checksum. La CLI è l'unica fonte di
verità per la selezione dei componenti.

Un modulo fallito, incluso un download con checksum non valido, viene interrotto
senza eseguire il file non verificato; gli altri moduli continuano. Al termine il
setup stampa il report `SUCCESS/FAILED` e restituisce codice 1 se ci sono errori.

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
./bin/create-vms.sh
./bin/set-wallpaper.sh
docker-runtime status
laptop-power-mode status
```
