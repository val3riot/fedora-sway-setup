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
  e un controllo Waybar: clic sinistro per avviare o focalizzare
  una finestra tiled, clic destro per chiudere il player.
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


## Barra Quickshell opzionale per Sway

Quickshell è un toolkit Qt/QML per componenti desktop. Questa integrazione
sostituisce la barra Waybar e gestisce le notifiche tramite il server nativo.
Launcher, lock screen, swayidle e policykit restano quelli della configurazione Sway.
Non è incluso implicitamente in `--sway`, `--all` o nei profili GNOME.

```bash
# Sway già configurato dal setup:
./install.sh --config-quickshell
# Prima installazione Sway:
./install.sh --sway --config-quickshell
```

Il flag installa e configura insieme; da solo non esegue il profilo `--dev`. Usa `quickshell`, `python3-gobject` e
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
- Audio: PipeWire nativo, selettori Output e Input, slider e mute separati;
  rotella barra ±5%, click centrale mute output. Volume limitato a 100%,
  default assenti e hotplug gestiti.
- Rete: libnm/NetworkManager via D-Bus, segnali e comandi asincroni espliciti,
  senza polling `nmcli`. `ETH`/`WIFI`/`NET off` indicano la connessione locale.
  Popup Ethernet con stato e IPv4; selettore Wi-Fi solo se esiste hardware.
- Bluetooth: widget `BT` solo con adapter disponibile. Stato attenuato se spento,
  accent con device connessi; popup nativo BlueZ con toggle, discovery e device.
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


### Selettori Wi-Fi, Bluetooth e audio

Il servizio libnm rileva soltanto dispositivi wireless reali. Senza Wi-Fi la
sezione scompare, senza placeholder o scansioni; Ethernet resta disponibile.
Gli AP vengono aggiornati da segnali, deduplicati per SSID originale e ordinati
con la rete connessa prima, poi per segnale decrescente. Per SSID duplicati si
mostra il segnale migliore, mantenendo il riferimento alla connessione corrente;
SSID nascosti restano distinti. Sono gestiti più adapter e AP rimossi.

Il toggle usa la proprietà D-Bus `WirelessEnabled`; la scansione esplicita usa
`request_scan_async`, limitata a una richiesta ogni 15 secondi per adapter.
Le reti salvate compatibili vengono attivate direttamente; NetworkManager
completa i profili delle reti aperte. Per nuove reti protette o nascoste si apre
`nm-connection-editor --create --type=802-11-wireless`: SSID, sicurezza e password
si inseriscono nel tool di sistema. Il popup non implementa un Secret Agent:
**nessuna password entra in QML, JSON, log, argomenti, environment o file temporanei**.
Per i profili salvati NetworkManager e il suo agent esistente gestiscono i segreti.
Il canale stdin del servizio accetta solo comandi con campi esplicitamente ammessi;
gli errori mostrati sono messaggi fissi, senza riversare eccezioni D-Bus o input.

Bluetooth usa `Quickshell.Bluetooth` 0.2.1 e BlueZ, senza `bluetoothctl` runtime.
Supporta adapter multipli, Enabled/Disabled/Enabling/Disabling/Blocked, elenco
connessi/associati/disponibili, connect/disconnect tramite `connected`, e batteria
solo quando `batteryAvailable` è vero (valore 0–1 convertito in percentuale).
`trusted` non viene modificato. Nessun MAC nella UI principale.

La ricerca è esplicita, dura al massimo 30 secondi e termina alla chiusura del
popup che l'ha avviata. Una discovery preesistente non viene acquisita o fermata.
La rimozione (`forget`) richiede una conferma nel popup. **Associa** sui dispositivi
nuovi e **Associa / Gestisci · BlueTUI** aprono direttamente la TUI in una Kitty
floating. Nessun tentativo `pair()` QML seguito da un manager grafico. Il click BT,
toggle, ricerca e connect/disconnect restano interni. BlueTUI gestisce le challenge
PIN/passkey/conferma numerica per i pairing avviati dalla TUI. Il suo agente non
sostituisce l'agente predefinito della sessione. Non automatizziamo trusted.
Quickshell 0.2.1 non espone errori dettagliati per tutte le operazioni: stato e
timeout segnalano un esito generico, senza retry. Blueman rimane disponibile
manualmente con `blueman-manager`; non viene avviato dal popup.

L'audio rimane responsabilità PipeWire, anche per cuffie Bluetooth. I nodi sono
filtrati per `audio`, `isStream`, `isSink` e `media.class` Audio/Sink o Audio/Source;
monitor e nodi virtuali vengono esclusi. `PwObjectTracker` associa i candidati
prima di leggere proprietà, volumi e mute. I selettori impostano
`preferredDefaultAudioSink` e `preferredDefaultAudioSource`; check, slider e mute
seguono i default effettivi. Un timeout segnala preferenze non applicate.
Non sono gestiti cambi di profilo hardware (es. A2DP/HFP): solo sink/source
che WirePlumber espone già nel graph. I popup hanno liste scrollabili limitate
in altezza. Nessun polling runtime di nmcli, bluetoothctl, wpctl, pactl o pw-cli.

Il doctor legge lo stato senza modificare radio, routing o device: Wi-Fi e
Bluetooth assenti sono opzionali, mentre hardware Bluetooth presente con BlueZ
irraggiungibile viene segnalato. Il test QML verifica l'API Bluetooth, PipeWire
ready ed enumerazione sink/source; i test con mock coprono hotplug e fallimenti.


## Notifiche native Quickshell

Il profilo Quickshell usa una sola istanza globale di
`Quickshell.Services.Notifications.NotificationServer`. Il servizio possiede
`org.freedesktop.Notifications`; un monitor Gio segue `NameOwnerChanged`, senza
polling o attivazione D-Bus, e segnala un altro daemon senza sostituirlo.

Toast in alto a destra, massimo quattro, sul monitor focused Sway (primo output
come fallback), senza duplicazione fra monitor. **NOT** nella barra apre il
centro condiviso e mostra il numero corrente, escludendo le transient. Icone e
immagini locali sono facoltative. Titolo e azioni restano testo semplice; il corpo
usa `StyledText` dopo `notifications/Markup.js`: **b**, *i*, u, newline ed entità
XML/numeriche; h1–h6 diventano grassetto, p/div separano righe. Tag non supportati
vengono rimossi conservando il testo; script/style e commenti vengono eliminati.
Attributi scartati, link non attivi, immagini HTML sostituite dall'alt text:
nessun contenuto remoto. `body-markup` è dichiarato; `body-hyperlinks` e
`body-images` restano disabilitati. I pulsanti invocano azioni native, non comandi.
I toast sono layer-shell **Overlay**, con keyboard focus **None**. I quick settings
sono finestre layer-shell **Top**, come la barra: nessun xdg-popup che possa
coprire i toast. Le notifiche sono visibili anche sopra utility floating e
fullscreen, senza sottrarre il focus o duplicarsi su altri monitor.
Inline reply è presente nell’API ma non è pubblicizzato né implementato.

Timeout applicativo rispettato (millisecondi nel pacchetto Fedora verificato,
nonostante la documentazione 0.2.1 dica secondi); valore zero senza scadenza.
Default: low 4 secondi, normal 7 secondi; poi il toast si nasconde e resta nel
centro. Le critical hanno bordo rosso e restano fino a chiusura esplicita.
Hover sospende il countdown. Le transient non entrano nel centro e scadono;
le resident seguono la semantica nativa delle azioni e non vengono chiuse da
**Pulisci normali**, che preserva anche le critical. La × permette la chiusura
individuale. Il centro è scrollabile. Notifiche e timestamp sopravvivono al
reload QML, senza ripetere i vecchi toast; nessuna cronologia viene salvata su
disco e un riavvio del processo azzera lo store.

La configurazione disabilita l’avvio diretto Mako da Sway, maschera i servizi
utente Mako/Dunst e sovrascrive l’attivazione D-Bus con un servizio mascherato.
Mako resta installato. File personali non riconosciuti vengono preservati con
un errore esplicito. Il setup conserva la scelta di rollback e crea un solo
backup `config.pre-notifications.bak`. Per migrare una sessione già avviata:

```bash
~/.local/bin/workstation-notifications.py quickshell
```

Il comando ferma la barra e l’esatto proprietario Mako del bus, verificato via
PID/executable, poi avvia Quickshell. Nessun kill di daemon al login. Rollback:

```bash
~/.local/bin/workstation-notifications.py mako
# Per tornare alle notifiche native:
~/.local/bin/workstation-notifications.py quickshell
```

Il rollback disabilita NotificationServer tramite il launcher, smaschera e
avvia Mako, ripristina autostart/attivazione. Non esiste fallback notifiche
automatico: se la barra ricade su Waybar, usare il rollback Mako esplicito.
Doctor verifica file, migrazione e proprietario del bus senza inviare notifiche.

Test: `bash tests/test-quickshell-notifications.sh` (migrazione e mock),
`python3 tests/test-notification-protocol.py` (API nativa su bus privato,
notify-send, azioni, close reasons, sostituzione, reload e collisione),
`python3 bin/test-quickshell-runtime.py` (QML e popup su due output isolati).


### System utility window policy

Applicazioni normali → **tiled**. Utility temporanee di sistema → **floating,
centrate, dimensione controllata**, senza workspace dedicato, sticky o fullscreen.
Kitty/tmux e Cliamp normali restano tiled. Il bordo viene dal tema Sway esistente.

`bin/configure-sway-windows.py` installa `62-system-utilities.conf` e il launcher
`~/.local/bin/workstation-system-tool`. Sono riservati soltanto gli app_id
`workstation-{bluetooth,audio,network,storage,system-monitor,system-tool}`.
Nessuna regola generale per Kitty. Il launcher usa `kitty --app-id`, eredita il
tema/padding/font globali e chiede 860×580 pixel, ridotti sui monitor piccoli.
Sway rende floating e centra la finestra. Una finestra già aperta viene focalizzata.
Niente `--hold`: quando la TUI termina, Kitty chiude e il layout tiled rimane intatto.

```bash
workstation-system-tool bluetooth
# Convenzione futura, senza implementare altri frontend:
workstation-system-tool system-tool -- nome-comando argomento
```

**BlueTUI 0.8.1** è il primo utilizzo. Fedora 44 `fedora`/`updates` non lo
pubblicano alla verifica del 2026-09-06. Il modulo Quickshell installa il binario
musl dalla [release ufficiale pythops/bluetui](https://github.com/pythops/bluetui/releases/tag/v0.8.1)
in `~/.local/bin/bluetui`, senza sudo/COPR/build locali. Versione, URL e digest
SHA-256 della release sono centralizzati in `config/sources.env` e `config/versions.env`.
`bash bin/install-bluetui.sh --check` verifica il binario senza eseguirlo;
l'installazione ripetuta non scarica nuovamente un binario già verificato e
preserva installazioni personali sconosciute. Il digest garantisce integrità
rispetto alla release ufficiale, non è una firma indipendente.

Nella TUI: `s` avvia/ferma ricerca, Tab cambia sezione, Invio associa o connette,
`q` chiude; i comandi disponibili sono riepilogati nella parte inferiore. PIN/passkey e conferma numerica hanno schermate
native. Non è un agente generale per tutte le richieste di autorizzazione BlueZ:
non aggiungiamo challenge artigianali né un fallback GUI automatico.
La configurazione 0.8.1 non espone una palette personalizzabile: si riusa il
contenitore Kitty tematizzato, senza patch upstream. BlueTUI aggiorna i dati
via D-Bus ogni secondo **solo mentre la TUI è aperta**; la shell Quickshell resta
event-driven e non esegue polling con `bluetoothctl` o altri comandi.
Bluetooth/BlueZ gestisce dispositivi e pairing; PipeWire continua a gestire
selezione Output/Input, volume e mute, anche per cuffie Bluetooth.

I dispositivi senza nome sono annunci per cui BlueZ non espone ancora un nome.
Un alias uguale all'indirizzo non nasconde più un `deviceName` valido. Il popup
mostra **Nome non disponibile** e offre l'indirizzo nei dettagli, senza inventare
nomi o identificarli dal solo MAC.

Le regole floating personalizzate sono riservate ai tool di sistema (PolicyKit,
rete, audio, Bluetooth e GNOME Settings). La vecchia regola cliamp viene rimossa;
il suo launcher avvia o porta in primo piano una normale finestra tiled e non
usa lo scratchpad. La migrazione `bin/configure-sway-windows.py` è idempotente,
preserva regole personali non riconosciute e conserva i backup fuori dagli include
Sway. Non cambia i bordi generali delle finestre.


### OSD, launcher, lock, screenshot e clipboard

La configurazione Quickshell include ora un **OSD** singolo, senza focus, sul
monitor attivo: volume/mute, microfono e luminosità backlight; si aggiorna sullo
stesso pannello e scompare dopo 1,6 secondi. Audio tramite il servizio PipeWire
esistente, brightnessctl solo alla pressione del tasto. Nessun polling aggiunto.

Il **launcher applicazioni** legge le desktop entries standard, filtra quelle
non avviabili e offre ricerca case-insensitive con ranking, icone, frecce,
Invio, click ed Esc. Non esegue il testo della ricerca come comando. Il precedente
`workstation-app-menu` resta disponibile e viene usato se Quickshell è assente.

Il **lock** resta il vero swaylock tramite `workstation-lock`, anche per swayidle
e before-sleep. Usa il wallpaper Sway gestito, fondo scuro, indicatore compatto,
accent arancione ed errore rosso. Swaylock stock 1.8.5 non supporta clock/data o
overlay dim: non sono simulati. `workstation-lock --check` valida le opzioni senza
bloccare la sessione; nessuna modifica all'autenticazione.

Gli **screenshot** usano grim/slurp e wl-copy: salvataggio in
`~/Pictures/Screenshots/Screenshot_YYYY-MM-DD_HH-MM-SS.png` (suffisso in caso di
collisione), copia PNG e breve notifica. Esc annulla l'area senza creare file.
Output e finestra usano le informazioni reali di Sway, inclusi offset negativi.

La **clipboard** è testuale e solo in memoria: wl-paste --watch alimenta un
piccolo store della sessione, massimo 100 elementi/2 MiB, 64 KiB per elemento.
Ricerca sul testo completo, anteprima troncata, frecce/Invio/click, Esc e Pulisci.
I dati marcati `sensitive`, incluso `x-kde-passwordManagerHint`, sono esclusi.
Nessun salvataggio su disco né logging; il riavvio di Quickshell azzera la
cronologia. Segreti non marcati dall'applicazione non sono riconoscibili in modo
affidabile: non vengono applicate euristiche. Pulisci svuota lo storico senza
alterare la clipboard corrente. Le immagini non entrano nello storico.

| Tasto | Azione |
|---|---|
| Mod+d | Launcher Quickshell |
| Mod+v | Clipboard history |
| Mod+Shift+v | Split verticale (spostato da Mod+v) |
| Print | Screenshot area |
| Shift+Print | Screenshot output attivo |
| Mod+Print | Screenshot finestra focused |
| XF86AudioRaiseVolume / LowerVolume | Volume + OSD |
| XF86AudioMute / MicMute | Mute output/microfono + OSD |
| XF86MonBrightnessUp / Down | Backlight + OSD, se disponibile |

Ctrl+V rimane invariato. I binding sono nel drop-in gestito
`92-desktop-tools.conf`; launcher, clipboard e OSD sono overlay, non finestre
tiled. Nessun nuovo flag di setup o pacchetto richiesto sulla workstation corrente.

### Desktop UX e Quick Settings

La shell integra Quick Settings, launcher, notifiche, OSD, clipboard, screenshot
ed utility di sistema floating. Il pulsante **QS** a destra apre un solo pannello
sul monitor cliccato: stato rete/Bluetooth, volume e mute output/input, CPU/RAM e
temperatura, Lock, Suspend e collegamento al power menu. I selettori completi
restano quelli esistenti: la navigazione chiude QS, senza sovrapporre pannelli.
I toast restano sul layer Overlay sopra QS (Top). Il pannello non prende focus
esclusivo: Esc lo chiude quando ha focus dopo un'interazione; sono sempre
disponibili Chiudi e il secondo click su QS. Nessuna azione di sessione nei test.

**Policy tema:** dark, foreground chiaro, superfici scure, accent e bordo focused
`#e88923`. GTK3 usa Adwaita integrato con prefer-dark, GTK4/libadwaita la preferenza
standard e accent orange ove supportato; niente CSS globale. Qt usa il plugin
Fedora `xdgdesktopportal`, che legge il color-scheme del portal e riusa i file
picker GTK. Non vengono aggiunti runtime Qt o library path.
Icone/cursore Adwaita, cursore 24 px, UI Adwaita Sans, monospace Cascadia Mono NF
(anche Kitty e swaylock), tutti già installati. Kitty mantiene i colori ANSI delle
applicazioni, con fondo scuro e selezione arancione. BlueTUI eredita Kitty.
Le applicazioni con palette proprie possono ignorare la preferenza o mantenere
un accent differente; GTK3 non offre l'accent arbitrario senza CSS.

Le app normali, inclusi Kitty, browser, IDE e file manager, restano tiled.
Sono floating soltanto le utility con identificatori riservati, i dialog Polkit
già gestiti e il file chooser `xdg-desktop-portal-gtk` (centrato, 800×600).
L'agente Polkit e i backend portal wlr/GTK restano quelli esistenti.
`configure-appearance.py` aggiorna solo le chiavi gestite, conserva gli altri
settings GTK e un solo backup per file; `--check` è diagnostico e non apre UI.
Le nuove variabili toolkit sono caricate da Fedora start-sway al login e dai
servizi utente; applicazioni/sessioni già avviate possono richiedere riapertura.

Shortcut principali invariati: Mod+d launcher, Mod+v clipboard,
Print/Shift+Print/Mod+Print screenshot area/output/finestra, XF86 audio/luminosità
con OSD. Waybar e gli helper di rollback restano disponibili.
