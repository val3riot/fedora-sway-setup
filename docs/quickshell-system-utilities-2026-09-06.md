# Utility floating, BlueTUI e notifiche — verifica 2026-09-06

Implementazione applicata al repository e alla configurazione della workstation.
I file QML installati sono identici ai template; le modifiche precedenti del
repository e il wallpaper personale sono stati preservati.

## Bluetooth e provenance

Versioni rilevate: Fedora 44, Quickshell
`0.2.1^git20260209.dacfa9d-5.fc44`, Kitty `0.47.1-1.fc44`,
BlueZ `5.87-4.fc44`, Blueman `2.4.6-7.fc44`.

Scelta **BlueTUI 0.8.1**, upstream https://github.com/pythops/bluetui,
release https://github.com/pythops/bluetui/releases/tag/v0.8.1.
Sorgente versionato dell'agente:
https://github.com/pythops/bluetui/blob/v0.8.1/src/agent.rs.
Il progetto implementa ingresso/display PIN e passkey, conferma numerica e
cancellazione delle richieste. L'agente è relativo alle proprie operazioni,
`request_default=false`; non è un sostituto generale di ogni autorizzazione BlueZ.

La query DNF limitata a `fedora`/`updates` non restituisce BlueTUI.
Installata la release ufficiale musl x86_64 in `~/.local/bin/bluetui`:
SHA-256 `c6d133930af3ef85d5fb6492c98982958619284d1f583c2c8ecf46992460d60e`.
Digest verificato prima dell'esecuzione; `file` rileva static PIE;
`bluetui --version` restituisce 0.8.1. URL/versioni/checksum, anche aarch64,
sono centralizzati in `config/sources.env`. Nessun sudo, RPM, COPR, fork o build
locale introdotto. La classificazione è **official upstream release binary**;
il checksum pubblicato dal progetto non viene presentato come firma indipendente.
Il secondo avvio dell'installer riusa il binario verificato senza download.

Nel popup restano toggle, discovery temporanea, stato, raggruppamento dispositivi,
batteria disponibile, connect/disconnect nativi e forget con conferma.
Le API Quickshell/BlueZ esistenti restano quelle del servizio unico:
`Bluetooth.adapters/defaultAdapter`, `adapter.enabled/discovering`,
`device.connected`, `batteryAvailable/battery`, `forget()`.
**Associa** e **Associa / Gestisci · BlueTUI** aprono la TUI direttamente;
non viene più chiamato `pair()` dal QML né preparato automaticamente Blueman.
Il popup si chiude quando viene lanciata la gestione. Blueman rimane installato
come strumento manuale (`blueman-manager`), mai come normale fallback del popup.
PipeWire mantiene tutte le responsabilità di routing, Output/Input, volume e mute.

La TUI eredita Kitty, senza duplicare la palette. BlueTUI 0.8.1 non offre una
palette configurabile e mantiene i propri colori interni. Non è stato patchato.
Il refresh D-Bus upstream di un secondo esiste solo durante la TUI aperta;
nessun polling di `bluetoothctl` e nessun nuovo polling nella shell.

## Policy finestre e prova reale

`workstation-system-tool` usa `kitty --app-id workstation-bluetooth`, senza
`--hold`, shell intermedia o workspace dedicato. Gli argomenti sono array argv.
La whitelist riserva anche audio/network/storage/system-monitor/system-tool,
senza implementare altri frontend. Il launcher focalizza un'utility già aperta.

`62-system-utilities.conf` applica floating, fullscreen disable e centratura solo
agli identificatori riservati; il bordo deriva da `99-theme.conf`. Kitty normale
e Cliamp restano tiled. Dimensione richiesta 860×580, ridotta in base alla
geometria logica dell'output corrente, quindi valida anche con scaling.

Verifica tramite click sul vero widget BT e sul pulsante Gestisci:

- nessuna apertura di Blueman Manager;
- BlueTUI effettivamente in esecuzione in Kitty;
- `get_tree`: `app_id=workstation-bluetooth`, `type=floating_con`;
- rettangolo reale 864×584 inclusi bordi, x=848/y=444 su 2560×1440;
- centrato nell'area disponibile sotto la barra da 32 pixel;
- due Kitty normali ancora tiled con geometria invariata dopo la chiusura;
- `q` di BlueTUI verificato separatamente su PTY: uscita naturale codice 0;
- test Sway isolato: la fine del comando chiude effettivamente Kitty.

Hardware reale: adapter hci0 acceso e discovery inizialmente/finalmente spenta.
All'apertura la TUI mostrava MX Keys Mini associata, disconnessa, non trusted.
Durante il lavoro il relativo oggetto è scomparso da BlueZ: il confronto completo
inizio/fine dell'elenco dispositivi **non passa**. Non sono stati inviati pairing,
forget, toggle o disconnessioni dai test; nessuna attribuzione della scomparsa
senza evidenza. È stato chiesto all'utente se stesse modificando l'associazione.
Non è stato tentato di ricreare o alterare l'associazione.
Il pairing autenticato con una nuova periferica **non è stato provato realmente**.

## Notifiche: causa e soluzione

I toast erano **già Overlay**. Il problema era la combinazione con quick settings
`PopupWindow`/xdg-popup: non garantiva l'ordine desiderato rispetto alle layer
surfaces. `BarPopup.qml` ora usa **PanelWindow Top**; i toast restano **Overlay**,
con `keyboardFocus=None` ed esclusione esplicita dalle zone riservate.
La soluzione non dipende dall'ordine di creazione QML.

L'HTML letterale derivava da `Text.PlainText` e capability markup disabilitata.
`Markup.js` normalizza b/i/u, newline ed entità XML/numeriche; h1–h6 diventano
b, p/div introducono interruzioni. Gli altri tag vengono rimossi conservando
il testo, img mantiene solo alt, script/style/commenti vengono eliminati.
Nessun attributo, URL o link attivo passa a `Text.StyledText`.
Tag malformati vengono bilanciati o eliminati senza crash. `body-markup=true`;
`body-hyperlinks/body-images=false`. Titoli e azioni restano PlainText.
Specifica verificata: https://specifications.freedesktop.org/notification/latest/markup.html.

Un solo store/server e stack globale, massimo quattro toast sul monitor focused;
center/count/transient/actions/timeout/critical e rollback Mako conservati.
Mako resta installato e disabilitato, senza daemon concorrente.
Ownership finale verificata: `/usr/bin/quickshell`, PID 54870 al momento del test.

Test reali `notify-send`: plain text, b/i/u, h1, entità, markup malformato,
body lungo, icona, low/normal/critical e stack multiplo. Ispezione screenshot:
bold/italic/underline effettivi, tag nascosti, wrapping/elisione corretti.
Notifica critical sopra il popup Bluetooth e sopra BlueTUI fullscreen;
focus Sway rimasto sulla TUI. Tutte le notifiche di prova chiuse tramite protocollo.
I test automatici verificano anche azioni, close reasons, sostituzioni, transient,
resident, timeout, count, clear, reload e collisione su bus privato.

## File di questa estensione

- Installazione/provenance: `bin/install-bluetui.sh`, `config/sources.env`,
  `bin/audit-urls.sh`, `modules/76-quickshell.sh`.
- Finestre: `bin/workstation-system-tool`, `bin/configure-sway-windows.py`,
  `templates/sway/config.d/62-system-utilities.conf`.
- Bluetooth QML: `services/BluetoothService.qml`, `popups/BluetoothPopup.qml`,
  `popups/BluetoothDeviceRow.qml`, `bar/Bar.qml` sotto `templates/quickshell`.
- Notifiche QML: `popups/BarPopup.qml`, `notifications/NotificationToastStack.qml`,
  `notifications/Markup.js`, `notifications/NotificationItem.qml`,
  `services/Notifications.qml` nella stessa directory.
- Doctor: `bin/doctor-quickshell.sh`.
- Test: `tests/test-system-utilities.py/.sh`, `tests/test-sway-windows.py`,
  `tests/test-bluetooth-popup.py`, `tests/test-notification-protocol.py`,
  fixture `quickshell/{markup,selectors,bluetooth-popup}.qml`.
- Documentazione: `README.md`, `AUDIT.md` e questo report.

## Risultati finali

- Suite completa `bash bin/test.sh`: **PASS**, inclusi ShellCheck, audit URL,
  segreti, test migrazione/idempotenza e `git diff --check`.
- Nuovi test: 18 casi markup eseguiti dal motore QML reale; helper argv/dimensioni,
  protezione file personali, pairing delegato senza manager GUI, confronto pixel
  toast sopra popup/floating/fullscreen, focus preservato e chiusura Kitty.
- QML runtime: **PASS**, due output isolati, barra, workspace, statistiche,
  rete, audio e tutti i popup; 44 check dei selettori mantenuti verdi.
- Doctor Quickshell: **PASS**, release BlueTUI/digest/helper/regole/markup/layer,
  ownership notifiche, API native e hardware opzionale senza mutazioni.
- Doctor generale: tre problemi preesistenti fuori ambito — link Docker Desktop
  `/usr/local/bin/docker`, agenti Claude e Copilot assenti.
- `systemd-analyze --user verify` e `sway --validate`: **PASS**.
- Servizio finale attivo, Quickshell in esecuzione; nessun processo Waybar/Mako
  concorrente né BlueTUI di test rimasto aperto. Nessun reboot/logout.

Limiti: pairing nuovo non provato; variazione dell'elenco BlueZ da chiarire;
nessun hardware Wi-Fi presente; più monitor verificati in Sway isolato, un solo
monitor reale. Il doctor generale conserva i tre problemi estranei sopra elencati.
