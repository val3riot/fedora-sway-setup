# Fedora 44 Workstation Setup v5

Bootstrap idempotente per una workstation Fedora 44 GNOME destinata allo sviluppo.
Lo script deve essere avviato come utente normale: richiede `sudo` solo per le operazioni di sistema.

## Contenuto

- cartelle XDG standard in inglese (`Downloads`, `Documents`, `Pictures`, ecc.);
- directory personali `~/Tools` e `~/Progetti`;
- Zsh e Oh My Zsh;
- ambiente terminale Kitty + tmux, con tema Zsh/Starship opzionale coordinato;
- strumenti di base, compilazione e diagnostica, incluso il browser Gitk;
- supporto per montare condivisioni SMB/CIFS tramite `cifs-utils`;
- Tailscale fondamentale, più supporto OpenVPN e OpenConnect/Cisco-compatible;
- SDKMAN con Java, Maven e Gradle;
- NVM con Node LTS;
- Miniconda senza attivazione automatica di `base`;
- LaTeX/TeX Live tramite i pacchetti ufficiali Fedora;
- Codex, Claude Code e GitHub Copilot CLI opzionali (`INSTALL_AGENTS=true`),
  tramite release e installer nativi ufficiali con versione e SHA-256 fissati;
- contesto macchina persistente in `~/.agent`, disponibile per qualunque agente;
- VS Code tramite repository RPM Microsoft;
- JetBrains Toolbox in `~/Tools`;
- DBeaver e Bruno via RPM;
- Discord e Obsidian via Flatpak/Flathub;
- Thunderbird e LibreOffice dai repository Fedora;
- Dash to Dock e pulsanti minimizza/massimizza per GNOME;
- desktop tiling Sway opzionale con Waybar, launcher Fuzzel e guida ricercabile;
- Docker Engine CE, Buildx e Docker Compose V2;
- Docker Engine in modalità Rootless vera, senza daemon root e senza gruppo `docker`;
- Docker Desktop per Linux (installato, non avviato automaticamente);
- KVM/QEMU + libvirt + virt-manager per VM Windows/Linux;
- Vagrant + provider libvirt per VM dichiarative e riproducibili;
- configurazione Git multi-account e multi-server;
- gestione energetica per laptop Intel tramite TuneD e `intel_pstate`.

## Uso

```bash
cp config/local.env.example config/local.env
# modifica config/local.env se necessario
./install.sh --development
```

Profilo minimo:

```bash
./install.sh --base
```

Durante l'esecuzione il setup mostra il modulo corrente, il conteggio e la
percentuale di avanzamento. L'output completo viene salvato anche in
`~/.local/state/fedora-workstation-setup/`; il percorso esatto del log è stampato
all'avvio e viene ripetuto se un modulo fallisce.

## Contesto macchina per gli agenti

Ogni esecuzione completa del setup crea, oppure aggiorna se già presente,
`~/.agent/AGENTS.md`. Il documento espone soltanto informazioni operative non
sensibili: sistema e architettura, percorsi convenzionali, componenti configurati,
regole per installare software e comandi di verifica del repository.

`~/.agent/LOCAL_NOTES.md` è invece creato soltanto quando manca e non viene mai
sovrascritto. Può contenere preferenze e vincoli aggiuntivi della macchina. Un
agente che non scopre automaticamente `~/.agent/AGENTS.md` deve essere istruito a
leggerlo all'inizio della sessione insieme a `LOCAL_NOTES.md`.

Il doctor verifica la presenza di entrambi:

```bash
./bin/doctor.sh
```

## Tema Zsh/Starship opzionale

La configurazione avanzata della shell si abilita con:

```bash
./install.sh --development --config-zsh-theme
# oppure
./install.sh --config-zsh-theme
```

Installa `zsh` e i due plugin dai repository Fedora e Starship dalla release
upstream verificata. Starship mostra directory, Git e operazioni
in corso, Docker, Kubernetes/namespace, Java, Maven, Node, Python, Conda, Vagrant,
durata dei comandi lenti, errori e job. Hostname e IPv4 compaiono soltanto via SSH.

URL, versione Starship e checksum SHA-256 sono centralizzati
in `config/sources.env`. Anche l'installer Oh My Zsh è fissato a un commit e verificato
prima dell'esecuzione. I file gestiti sono `~/.config/starship.toml` e
`~/.config/workstation-setup/zsh-theme.zsh`; `.zshrc` riceve un solo blocco marcato.
Al primo intervento viene conservato `~/.zshrc.workstation-setup.bak`.

## Terminale: Kitty + tmux

Kitty è il contenitore grafico: cura rendering GPU, font monospace Fedora, colori,
scrollback, URL e clipboard. tmux è invece il workspace manager persistente per
sessioni, window e pane. Entrambi sono installati e configurati dal profilo
development e da `--all`:

```bash
./install.sh --development
# oppure: --all
```

Le configurazioni sono `~/.config/kitty/kitty.conf` e `~/.tmux.conf`. Se esiste un
file personale non gestito, la prima esecuzione lo conserva accanto all'originale
con suffisso `.workstation-setup.bak`; il backup non viene moltiplicato. Kitty si
ricarica aprendo una nuova finestra (oppure con `kitty @ load-config` se il remote
control è stato abilitato personalmente). tmux si ricarica con `Ctrl+b r`.

Kitty mantiene queste scorciatoie per la clipboard:

| Scorciatoia | Operazione |
|---|---|
| `Ctrl+Shift+A` | Copy entire terminal scrollback |
| `Ctrl+Shift+C` | Copy selection |
| `Ctrl+Shift+V` | Paste |

`Ctrl+Shift+A` copia come testo semplice lo schermo e tutto lo scrollback
disponibile nel buffer della finestra Kitty corrente. `Ctrl+A` resta volutamente
libero e raggiunge shell/readline/Zsh con il significato standard di inizio riga.
Kitty mantiene anche `Ctrl+Shift+U` per gli URL hints e non definisce split o tab
custom. Usa `xterm-kitty`, mentre tmux espone
`tmux-256color` alle applicazioni e dichiara RGB/clipboard tramite
`terminal-features`. `set-clipboard on` usa le sequenze terminale/OSC 52 e funziona
su Wayland senza dipendere da helper X11; la copia resta semplicemente interna a
tmux se il terminale esterno non offre la clipboard.

La scorciatoia è gestita da Kitty anche quando la finestra contiene tmux e non
interferisce con il prefix `Ctrl+b`. Lo scrollback di Kitty non equivale però alla
history interna di tmux: contenuto conservato soltanto da tmux (per esempio per
l'uso dell'alternate screen) non può essere recuperato dal buffer esterno di Kitty.

tmux mantiene il prefix standard `Ctrl+b`. In breve: il server tmux ospita una o
più sessioni; ogni sessione contiene window, e ogni window contiene pane.

| Operazione | Comando / tasto |
|---|---|
| crea o collega `dev` | `tmux new -As dev` |
| elenca / collega sessioni | `tmux ls` / `tmux attach -t nome` |
| detach | `Ctrl+b d` |
| nuova window / precedente / successiva | `Ctrl+b c` / `Ctrl+b p` / `Ctrl+b n` |
| scegli sessione | `Ctrl+b s` |
| split destra / sotto | `Ctrl+b \|` / `Ctrl+b -` |
| naviga pane | `Ctrl+b h/j/k/l` |
| ridimensiona di 5 celle | `Ctrl+b H/J/K/L` |
| chiudi pane | `exit` oppure `Ctrl+b x` |
| copy mode / copia selezione | `Ctrl+b [` / `v`, poi `y` |
| reload config | `Ctrl+b r` |

Kitty usa correttamente `TERM=xterm-kitty`; il setup non sostituisce o avvolge il
comando `ssh`, che rimane il client OpenSSH standard. Il collegamento si effettua
sempre normalmente con `ssh user@host`. Se il sistema remoto conosce già
`xterm-kitty` non serve altro; in caso contrario, dopo avere configurato l'accesso
SSH, preparare una volta quella specifica combinazione utente/host con:

```bash
./bin/install-kitty-terminfo-remote user@host
# oppure, dopo avere eseguito il setup:
install-kitty-terminfo-remote user@host
```

L'helper legge localmente `xterm-kitty` con `infocmp`, lo invia tramite OpenSSH e lo
compila sul remoto con `tic` in `~/.terminfo`, senza `sudo` e senza modificare shell,
configurazione SSH o `TERM`. È idempotente e accetta anche alias di `~/.ssh/config`.
Non effettua connessioni durante il normale setup. `kitten ssh` resta disponibile
come funzione manuale di Kitty, ma non viene usato automaticamente né è necessario
nel workflow predefinito.

OpenSSH trasmette il valore di `TERM`, ma non il relativo database terminfo: non
esiste quindi una configurazione esclusivamente locale di Kitty che possa rendere
`xterm-kitty` disponibile su qualunque distribuzione remota. Per ottenere questo
risultato senza preparare i singoli account bisognerebbe usare automaticamente
`kitten ssh` oppure degradare `TERM`; il setup evita entrambe le modifiche.

Con tmux annidato, `Ctrl+b Ctrl+b` invia il prefix al livello interno. Dopo avere
installato il terminfo remoto, tmux può essere avviato da una sessione SSH con
`TERM=xterm-kitty` e continua poi a esporre `tmux-256color` alle applicazioni.

Per impostare Kitty come terminale predefinito tramite il meccanismo standard di
Fedora, usare in `config/local.env`:

```bash
SET_KITTY_AS_DEFAULT_TERMINAL=true
```

L'opzione installa `xdg-terminal-exec` e gestisce
`~/.config/xdg-terminals.list`, conservando l'eventuale file personale come
`~/.config/xdg-terminals.list.workstation-setup.bak`.

## Wallpaper

Inserisci uno o più file JPG, PNG o WebP nella cartella `wallpapers/`, quindi
scegli quello da applicare a GNOME con:

```bash
./install.sh --set-wallpaper
```

Il comando mostra un elenco numerato e configura l'immagine scelta sia per il
tema chiaro sia per quello scuro.

## Applicazioni desktop

La sezione desktop installa Thunderbird e LibreOffice dai repository Fedora,
Discord e Obsidian per il singolo utente da Flathub e Dash to Dock per GNOME.

Le applicazioni sono abilitate per impostazione predefinita e possono essere escluse in `config/local.env`:

```bash
INSTALL_DISCORD=false
INSTALL_OBSIDIAN=false
INSTALL_THUNDERBIRD=false
INSTALL_LIBREOFFICE=false
INSTALL_DASH_TO_DOCK=false
ENABLE_WINDOW_BUTTONS=false
```

Per installare soltanto la sezione desktop:

```bash
./install.sh --gnome-desktop
```

`--desktop` resta un alias compatibile. Questa modalità esegue il profilo GNOME
senza installare il profilo development completo. Dopo la prima installazione
di Dash to Dock può essere necessario un logout/login per caricare l'estensione.

## Desktop tiling Sway

Il profilo installa `templates/sway/config.d/99-theme.conf` in
`~/.config/sway/config.d/99-theme.conf`, caricato dal `layered-include` Fedora.
Il tema usa bordi da 2 px per finestre normali e floating: arancione `#ff8c00`
per quella attiva, grigio `#242424` per le inattive e rosso `#ff3b30` per le
urgenti. Il template principale lascia questi colori al file dedicato.

Il profilo sperimentale installa una sessione Sway affiancata a GNOME usando
soltanto pacchetti dei repository Fedora. GNOME non viene rimosso e resta
selezionabile dalla schermata di login:

```bash
./install.sh --sway-desktop
```

I profili desktop sono indipendenti e componibili. Per preparare nello stesso
passaggio strumenti di sviluppo e Sway:

```bash
./install.sh --development --sway-desktop
```

È anche possibile installare entrambe le sessioni desktop con
`./install.sh --gnome-desktop --sway-desktop`. `--all` conserva il significato
storico di `--development --gnome-desktop` e non abilita implicitamente Sway.

Il desktop usa Waybar, Kitty e Fuzzel. `Super+D` apre il launcher applicazioni;
`Super+G` apre una palette ricercabile con scorciatoie e comandi. La stessa guida
si avvia dal launcher cercando **Sway Help & Keybindings**, oppure da terminale
con `sway-help`. Selezionando una voce, questa viene anche copiata negli appunti.

| Scorciatoia | Azione |
|---|---|
| `Super+D` | launcher applicazioni |
| `Super+G` | guida ricercabile |
| `Super+Invio` | terminale Kitty |
| `Super+H/J/K/L` | cambia focus |
| `Super+Shift+H/J/K/L` | sposta finestra |
| `Super+1…9` | cambia workspace |
| `Super+Shift+1…9` | sposta finestra nel workspace |
| `Super+Shift+C` | ricarica Sway |
| `Super+Shift+E` | termina la sessione |

Le configurazioni gestite sono in `~/.config/sway`, `~/.config/waybar` e
`~/.config/fuzzel`; un file personale preesistente viene salvato una sola volta
con suffisso `.workstation-setup.bak`. Il contesto `~/.agent/AGENTS.md` documenta
automaticamente desktop, percorsi, launcher e comandi, così gli agenti possono
diagnosticare e modificare il setup in modo riproducibile.

Per installare sia l'ambiente di sviluppo sia il profilo GNOME:

```bash
./install.sh --all
```

`--develop` è un alias di `--development`.

Per visualizzare una guida rapida dei comandi disponibili e degli alias creati,
senza eseguire l'installazione:

```bash
./install.sh --help
```

Per verificarne poi l’installazione:

```bash
flatpak info --user com.discordapp.Discord
flatpak info --user md.obsidian.Obsidian
rpm -q thunderbird libreoffice-core
./bin/doctor.sh
```

## Provenienza e sicurezza

La policy e il report sono in `AUDIT.md`. Il doctor include il controllo locale di
path, RPM, repository vendor, copie shadowing e metodo degli agenti; la verifica URL
online resta separata per non rendere il doctor dipendente dalla rete:

```bash
./bin/provenance-audit.sh
./bin/audit-urls.sh --online
./bin/check-secrets.sh
```

## Aggiornamento del sistema e delle app

Il modulo della shell configura l’alias:

```bash
update-a
```

che esegue in sequenza `sudo dnf upgrade --refresh -y` e `flatpak update -y`. L’aggiornamento Flatpak parte solo se quello Fedora termina correttamente.

Controllo sintattico senza installare nulla:

```bash
./bin/check-setup.sh
```

Verifica della workstation:

```bash
./bin/doctor.sh
```

## Condivisioni SMB/CIFS

Il pacchetto `cifs-utils` viene installato in entrambi i profili e fornisce
`mount.cifs`, necessario per montare condivisioni SMB da terminale o tramite
`/etc/fstab`.

Verifica dell'installazione:

```bash
rpm -q cifs-utils
command -v mount.cifs
./bin/doctor.sh
```

Esempio di test con una condivisione SMB (sostituisci server, condivisione e
utente):

```bash
sudo mkdir -p /mnt/smb-test
sudo mount -t cifs //server/condivisione /mnt/smb-test \
  -o username=utente,vers=3.0
mountpoint /mnt/smb-test
sudo umount /mnt/smb-test
```

La password viene richiesta interattivamente da `mount.cifs`, evitando di
inserirla nella cronologia della shell.

## Cartelle standard in inglese

Con il valore predefinito:

```bash
USE_ENGLISH_XDG_DIRS=true
```

il setup configura:

- `Scaricati` → `Downloads`;
- `Documenti` → `Documents`;
- `Immagini` → `Pictures`;
- `Musica` → `Music`;
- `Video` → `Videos`;
- `Scrivania` → `Desktop`;
- `Modelli` → `Templates`;
- `Pubblici` → `Public`.

Se sia la cartella italiana sia quella inglese contengono file, il modulo non le unisce automaticamente e mostra un avviso per evitare sovrascritture.

## Gestione energetica

Il modulo `90-power-mode.sh`:

1. installa e abilita TuneD/tuned-ppd;
2. conserva una copia sorgente in `~/Tools/laptop-power-mode/laptop-power-mode.sh`;
3. installa l’eseguibile root-owned `/usr/local/bin/laptop-power-mode`;
4. collega `~/.local/bin/laptop-power-mode` alla copia di sistema, sostituendo eventuali vecchi link;
5. crea `/etc/laptop-power-mode.conf`;
6. crea e abilita `laptop-power-mode.service`;
7. applica al boot la modalità configurata.

Configurazione predefinita:

```bash
POWER_MODE_AUTOSTART=true
POWER_MODE_DEFAULT="dev"
POWER_MODE_DEV_MAX=60
POWER_MODE_QUIET_MAX=45
POWER_MODE_MIN_PERF=10
```

Comandi disponibili:

```bash
laptop-power-mode status
laptop-power-mode dev       # usa POWER_MODE_DEV_MAX
laptop-power-mode dev 70
laptop-power-mode quiet     # usa POWER_MODE_QUIET_MAX
laptop-power-mode normal    # balanced, 100%, turbo attivo
laptop-power-mode full      # performance, 100%, turbo attivo
laptop-power-mode default   # riapplica il valore configurato
```

Per i test termici usa:

```bash
laptop-power-mode normal
```

Per lo sviluppo quotidiano:

```bash
laptop-power-mode dev
```

Il servizio usa `/usr/local/bin/laptop-power-mode`, non il file nella home, così evita problemi di esecuzione dei servizi di sistema e di contesto SELinux.

Dopo una modifica manuale della copia in `~/Tools`, sincronizzala e riapplica il profilo con:

```bash
sudo install -m 0755 \
  ~/Tools/laptop-power-mode/laptop-power-mode.sh \
  /usr/local/bin/laptop-power-mode
sudo restorecon -F /usr/local/bin/laptop-power-mode
sudo systemctl restart laptop-power-mode.service
```

Verifica del servizio:

```bash
systemctl status laptop-power-mode.service
journalctl -u laptop-power-mode.service -b --no-pager
```

Per disattivare l’applicazione automatica al boot imposta in `config/local.env`:

```bash
POWER_MODE_AUTOSTART=false
```

poi riesegui il setup.

## Più identità Git

Esegui una volta per ogni combinazione account/server/directory:

```bash
./bin/add-git-identity.sh
```

Esempi di profili indipendenti:

- `personal-github` per `~/Progetti/personali/github/`;
- `azienda-github` per `~/Progetti/lavoro/azienda/github/`;
- `cliente-gitlab` per `~/Progetti/lavoro/cliente/gitlab/`;
- `gitea-interno` per `~/Progetti/lavoro/azienda/gitea/`.

L’identità Git viene scelta dalla directory del repository; la chiave SSH viene scelta dall’alias usato nel remote.

## Docker

La v5 usa Docker Rootless come runtime container predefinito. La configurazione standard è:

```bash
INSTALL_PODMAN=false
INSTALL_DOCKER=true
INSTALL_DOCKER_DESKTOP=true
DOCKER_ROOTLESS=true
DOCKER_ROOTLESS_AUTOSTART=true
```

Il modulo `55-docker.sh` configura il repository RPM ufficiale Docker e installa:

- `docker-ce`;
- `docker-ce-cli`;
- `containerd.io`;
- `docker-ce-rootless-extras`;
- `docker-buildx-plugin`;
- `docker-compose-plugin`.

Con `DOCKER_ROOTLESS=true` il daemon Docker e i container vengono eseguiti nello user namespace dell’utente. `docker ps`, `docker build` e `docker compose` funzionano senza `sudo`, mentre il daemon di sistema resta disabilitato.

Docker Desktop viene installato dal pacchetto RPM ufficiale in `/opt/docker-desktop`. Su GNOME viene installata anche l'estensione AppIndicator e l'utente viene aggiunto al gruppo `kvm` quando disponibile. Il primo avvio di Docker Desktop va fatto dall'applicazione grafica per accettare i termini.

Docker Desktop e Docker Engine possono coesistere, ma usano storage e daemon separati. Per evitare consumo di risorse e conflitti sulle porte, la v5 lascia Docker Rootless come runtime predefinito e non abilita Docker Desktop all'accesso. È disponibile il comando:

```bash
docker-runtime status
docker-runtime rootless
docker-runtime desktop
```

`docker-runtime desktop` ferma il daemon rootless prima di avviare Desktop; `docker-runtime rootless` ferma Desktop e torna al context `rootless`.

Podman si abilita con:

```bash
INSTALL_PODMAN=true
```

## Aggiornamento di sistema

Per evitare che ogni esecuzione del setup avvii anche un aggiornamento completo:

```bash
RUN_SYSTEM_UPGRADE=false
```

Il valore predefinito resta `true`.

## Sicurezza e riproducibilità

Gli URL usati dagli installer sono raccolti in:

```text
config/sources.env
```

Il file contiene fonti, versioni e SHA-256 di Oh My Zsh, Starship, NVM,
Miniconda, Codex, Claude Code, Copilot CLI, Docker Desktop e DBeaver. Bruno e
JetBrains Toolbox verificano i checksum pubblicati dalle rispettive API vendor.
`config/local.env` può sovrascrivere i valori.

## Docker Rootless

Configurazione predefinita:

```bash
INSTALL_DOCKER=true
DOCKER_ROOTLESS=true
DOCKER_ROOTLESS_AUTOSTART=true
INSTALL_DOCKER_DESKTOP=true
```

Il modulo installa `docker-ce-rootless-extras`, verifica `newuidmap/newgidmap` e almeno 65.536 subordinate UID/GID, disabilita il daemon Docker di sistema e crea il servizio systemd utente `docker.service`. Con autostart attivo abilita anche il linger dell’utente.

Runtime disponibili:

```bash
docker-runtime status
docker-runtime rootless
docker-runtime desktop
```

## Virtualizzazione KVM/QEMU

Il profilo `development` installa:

- KVM/QEMU;
- libvirt e rete NAT predefinita;
- `virt-manager` per la GUI;
- `virsh`, `virt-install` e `virt-viewer` per CLI e automazione;
- Vagrant + `vagrant-libvirt` per ambienti VM riproducibili da `Vagrantfile`;
- OVMF/UEFI;
- `swtpm` per TPM virtuale, utile per guest Windows moderni.

Avvio:

```bash
virt-manager
```

Controlli:

```bash
ls -l /dev/kvm
virsh -c qemu:///system list --all
```

Dopo la prima installazione può essere necessario logout/login per applicare i gruppi `kvm` e `libvirt`. Per workflow DevOps puoi poi usare `vagrant up --provider=libvirt`.

### VM opzionali: Debian, Fedora e Windows 11

Il setup può creare tre VM persistenti da ISO locali. La funzione è disabilitata
di default, non scarica immagini automaticamente e non modifica VM omonime già
esistenti. Copia le ISO in `~/ISO` (oppure configura percorsi diversi) e aggiungi
a `config/local.env`:

```bash
CREATE_OPTIONAL_VMS=true
VM_DEBIAN_ISO="$HOME/ISO/debian.iso"
VM_FEDORA_ISO="$HOME/ISO/fedora.iso"
VM_WINDOWS11_ISO="$HOME/ISO/windows11.iso"
```

Quindi esegui `./install.sh --development`. In alternativa puoi creare i guest
manualmente, tutti o singolarmente:

```bash
./bin/create-vms.sh all
./bin/create-vms.sh debian
./bin/create-vms.sh fedora windows11
```

Debian e Fedora ricevono 2 vCPU, 4 GiB di RAM e dischi da 40/50 GiB. Windows 11
riceve 4 vCPU, 8 GiB di RAM, un disco da 80 GiB, UEFI e TPM 2.0 virtuale. Le
installazioni restano interattive e si completano aprendo `virt-manager`.

## Barra Quickshell opzionale per Sway

Quickshell è un toolkit Qt/QML per componenti desktop. Questa integrazione V1
sostituisce **solo la barra Waybar**: notifiche, launcher, lock screen, swayidle,
policykit e gli altri componenti restano quelli della configurazione Sway.
Non è incluso implicitamente in `--sway-desktop`, `--all` o nei profili GNOME.

```bash
# Sway già configurato dal setup:
./install.sh --config-quickshell
# Prima installazione Sway:
./install.sh --sway-desktop --config-quickshell
```

Il flag installa e configura insieme, come `--config-zsh-theme`; da solo non
esegue il profilo development. Usa `quickshell`, `python3-gobject` e
`NetworkManager-libnm` esclusivamente dai repository **Fedora official**
`fedora` e `updates`, con verifiche DNF/GPG normali. Le fonti verificate sono
centralizzate in `config/sources.env`; vedere anche `AUDIT.md`.
La guida upstream menziona il COPR `errornointernet/quickshell`: è una fonte
**upstream-recommended, non Fedora official**, e qui **non viene abilitato**,
perché il pacchetto è disponibile direttamente in Fedora 44.

La barra, alta 32 px, usa fondo `#111111`, testo `#dddddd`, accent `#e88923`,
grigi per stati inattivi, giallo per warning e rosso per criticità. Non richiede
Nerd Fonts. Layout:

```text
workspace numerici                  CPU  RAM  temperatura  NET  VOL  orologio  ⏻
```

- Workspace: oggetti nativi `Quickshell.I3`, aggiornamento IPC immediato e click
  per attivarli; arancione focused, chiaro occupied, grigio empty, rosso urgent.
  Un piccolo subscriber IPC Python legge l'albero solo su eventi per distinguere
  workspace realmente vuoti, dato non esposto dal modello nativo. Niente polling
  `swaymsg`. I workspace esistenti sono filtrati per output; gli slot liberi 1–10
  sono mostrati sull'output focused. I workspace numerici oltre 10 sono inclusi;
  quelli senza numero sono fuori dal layout V1.
- CPU: delta `/proc/stat` fra campioni, escludendo il doppio conteggio guest;
  primo campione e delta invalidi mostrano `—`. RAM: `MemTotal - MemAvailable`.
  Temperatura: detection hwmon per driver/label CPU e fallback thermal per tipo,
  senza indici fissi; se assente, il dato è nascosto. Un solo processo condiviso
  campiona ogni 2 secondi, con nuova detection sensori ogni 60 secondi.
- Audio: PipeWire nativo, click apre volume/slider/mute/output; rotella ±5%,
  click centrale mute. Volume limitato a 100%, uscita assente gestita.
- Rete: libnm/NetworkManager via D-Bus, solo segnali, senza polling `nmcli`.
  `NET`/`NET off` indicano la connessione locale (non la raggiungibilità Internet).
  Popup con Ethernet/Wi-Fi, stato, interfacce, IPv4 e SSID disponibile.
- Clock nativo al minuto, locale italiano; click apre calendario QML con mese,
  anno, settimana da lunedì, oggi evidenziato e navigazione mesi.
- Power: il simbolo apre un menu; serve un secondo click su Lock, Logout,
  Suspend, Reboot o Shutdown. Lock riusa `~/.local/bin/workstation-lock` se
  presente, altrimenti lo `swaylock` del template; logout usa `swaymsg exit`,
  alimentazione usa `systemctl`. I test disabilitano tutte queste azioni.

La configurazione risiede in `~/.config/quickshell/workstation/`: `shell.qml`,
`Theme.qml`, componenti in `bar/`, `popups/`, servizi in `services/`.
Viene creata una `PanelWindow` per schermo, senza nomi output fissi, con exclusive
zone 32 px e layer Top (le finestre fullscreen Sway coprono la barra e gli
eventuali popup vengono chiusi tramite eventi IPC).
Le statistiche e i servizi sono condivisi fra monitor. I popup si chiudono con
Chiudi/Annulla oppure ricliccando il modulo; non c'è chiusura al click esterno.
Layout pensato per output desktop di almeno circa 900 px logici.

### Attivazione, restart e rollback

La configurazione ha effetto al **prossimo login Sway**. Il setup non riavvia
la sessione né sostituisce la barra attiva durante l'installazione.
Il drop-in `~/.config/sway/config.d/90-bar.conf` sostituisce quello Fedora tramite
`layered-include` e avvia `workstation-bar.service`. Eventuali `exec waybar`
standard nel file managed vengono disabilitati; il resto viene preservato.
La scelta persiste in `~/.config/workstation-setup/bar`, anche rieseguendo il
profilo Sway senza il flag. Una nuova workstation senza flag continua a usare Waybar.

Dopo il primo login con questa configurazione:

```bash
# Quickshell ricarica automaticamente i QML salvati; restart esplicito:
~/.local/bin/workstation-bar.sh restart
journalctl --user -u workstation-bar.service -b
# Rollback immediato e persistente, senza disinstallare nulla:
~/.local/bin/workstation-bar.sh waybar
# Riabilitazione:
~/.local/bin/workstation-bar.sh quickshell
```

Il servizio gestisce un solo backend e un lock impedisce avvii duplicati. Se
Quickshell termina con errore, viene avviata Waybar come fallback; la scelta
persistente resta Quickshell per consentire un nuovo tentativo con `restart`.
Waybar e le sue configurazioni non vengono rimosse. Per un ripristino manuale
completo, fermare il servizio, ripristinare `config.pre-quickshell.bak` e rimuovere
il solo drop-in managed `90-bar.conf`, poi fare logout/login.

La migrazione rifiuta configurazioni non managed, avvii barra non riconosciuti,
include personali ambigui o un `90-bar.conf` personale non vuoto, senza modificarli.
Crea un solo backup Sway. Un manifest di hash protegge i QML modificati a mano:
un aggiornamento che li sovrascriverebbe viene rifiutato e indica il file da
riconciliare. Il profilo corrente usa `~/.config`; un `XDG_CONFIG_HOME` alternativo
viene rifiutato esplicitamente. Gli autostart desktop e i servizi utente abilitati riconoscibili per Waybar o
Quickshell vengono rifiutati: vanno prima disabilitati. Wrapper esterni arbitrari
non sono analizzabili automaticamente e devono essere verificati dall’utente.

```bash
./bin/doctor.sh
./bin/doctor-quickshell.sh
python3 bin/test-quickshell-runtime.py
./bin/test.sh
```

Quickshell 0.2.1 non espone un comando standalone di validazione QML: il test
runtime carica il vero entrypoint in uno Sway headless temporaneo, poi prova i
componenti e tutti i popup su due output. Non usa l'IPC del compositor corrente
né esegue azioni di alimentazione. Il doctor esegue questo test solo quando la
feature è selezionata e i prerequisiti sono presenti; verifica anche RPM, file,
dipendenze, conflitti barra e URL. La suite ordinaria usa fixture per migrazione,
rollback, CLI e statistiche e non richiede una sessione grafica.


Il controllo `bin/check-quickshell-runtime.sh` distingue RPM installato,
eseguibile disponibile e runtime caricabile. Usa `LD_BIND_NOW=1 quickshell
--version` con timeout: risolve anche i simboli lazy senza avviare una barra.
Verifica inoltre path canonici e vendor RPM delle librerie Qt risolte da `ldd`.
Il modulo Quickshell interrompe la configurazione se questo controllo fallisce.

Su Fedora 44, Quickshell `0.2.1^git20260209.dacfa9d-5.fc44` con Qt
`6.11.1` può soddisfare le dipendenze RPM ma fallire sul costruttore
`QUntypedPropertyBinding(QPropertyBindingPrivate*)`: il binario richiede
`Qt_6`, mentre Qt Core 6.11.1 lo esporta come `Qt_6.11_PRIVATE_API`.
Qt Core Fedora `6.11.2-2.fc44` esporta la versione richiesta. Prima di
correggere, confrontare gli RPM installati con i metadata DNF e controllare
l'environment della shell e di `systemctl --user show-environment`.
Per questo disallineamento verificato, esaminare la transazione con:

```bash
sudo dnf --refresh --repo=fedora --repo=updates upgrade --assumeno quickshell 'qt6-*'
# Se la transazione è coerente, ripetere senza --assumeno.
```

Non occorre reinstallare Quickshell, modificare QML o eseguire un distro-sync
globale. Il setup non effettua aggiornamenti globali automatici: il controllo
preventivo segnala il problema prima di cambiare la configurazione desktop.
