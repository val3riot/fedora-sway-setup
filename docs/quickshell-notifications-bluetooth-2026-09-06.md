# Notifiche e Bluetooth — verifica 6 settembre 2026

Implementazione sulla Fedora 44 corrente, Quickshell
`0.2.1^git20260209.dacfa9d-5.fc44`, Qt 6.11.2. Nessun pacchetto aggiunto,
nessuna modifica a NetworkManager, routing PipeWire, Sway workspace o fallback
Waybar. Le precedenti estensioni Wi-Fi/audio/Bluetooth sono state riutilizzate.

## Notifiche

Componenti: `services/Notifications.qml`, `services/notification-bus.py`,
`notifications/NotificationEntry.qml`, `NotificationItem.qml`,
`NotificationToastStack.qml`, `popups/NotificationCenter.qml`,
`bar/Notifications.qml`; collegati da `shell.qml` e `bar/Bar.qml`.
`ActionButton.qml` usa testo semplice anche per etichette non fidate.

API nativa NotificationServer: tracking, keepOnReload, capabilities esplicite,
Notification.expire/dismiss, NotificationAction.invoke. Inline reply disponibile
nell'API ma non implementato/pubblicizzato. Markup e hyperlink non pubblicizzati:
il contenuto viene mostrato come PlainText. Icone mancanti non generano riquadri
placeholder; i percorsi image://icon vengono verificati contro il tema.

Il timeout esposto dall'RPM installato è in **millisecondi**: un Notify D-Bus con
120 restituisce expireTimeout 120, contrariamente alla descrizione “seconds”
della documentazione 0.2.1. Il test nativo verifica la scadenza reale. Default
low/normal 4/7 secondi, poi centro; timeout esplicito chiude, zero non scade,
critical persistente fino a chiusura. Hover sospende il timer. Resident mantiene
la semantica nativa delle azioni; clear preserva resident e critical. Transient
solo toast, esclusa dal count. Massimo quattro toast, un solo stack sul monitor
focused, store unico fra barre; centro scrollabile per ogni barra.

Reload verificato: ID/count mantenuti, timestamp memorizzati con
PersistentProperties come JSON string (non oggetti JS tra engine), vecchi toast
non riproposti. Nessuna persistenza su disco; restart del processo azzera lo store.

Migrazione tramite `bin/workstation-notifications.py` e
`bin/configure-quickshell.py`: avvio Mako commentato nel config managed Sway,
`95-notifications.conf`, selettore `~/.config/workstation-setup/notifications`,
mask unit utente Mako/Dunst e activator D-Bus utente deterministico.
Mako RPM conservato. Il monitor ownership è Gio/NameOwnerChanged, senza polling.
Configurazioni personali ambigue vengono rifiutate prima delle scritture.
Backup del config una sola volta, scelta mako conservata dai setup successivi.

Ownership reale prima: Mako PID 2106. Migrazione, rollback Mako e ritorno
Quickshell eseguiti con successo. Proprietario finale verificato:
`/usr/bin/quickshell`, configurazione `~/.config/quickshell/workstation`.
Mako assente fra i processi; workstation-bar.service attivo. Nessun fallback
notifiche automatico: in caso di fallback barra Waybar scegliere Mako esplicitamente.

Rollback: `~/.local/bin/workstation-notifications.py mako`;
ritorno: `~/.local/bin/workstation-notifications.py quickshell`.

## Bluetooth

Servizio esistente esteso, nessun backend parallelo. Click BT apre il popup;
ricerca posizionata sopra la lista per non spostarsi quando compaiono device.
Toggle `adapter.enabled`, discovery `adapter.discovering`, connect/disconnect
`device.connected`, pairing `pair()`/`cancelPair()`, forget con conferma tramite
`forget()`. Nessuna modifica automatica a trusted. Batteria solo quando
batteryAvailable; classificazione Audio/Mouse/Tastiera/Controller/Telefono.
Il routing delle cuffie rimane esclusivamente nel selettore PipeWire.

Pairing nativo prima; fallback esterno solo con click esplicito dopo pairing
non completato, se richiede PIN/conferma. L'API installata non espone challenge
né errori strutturati sufficienti per identificare con certezza un fallimento
autenticato: il messaggio non presenta ogni errore come richiesta PIN.
Blueman già installato viene rilevato dall'helper, nessun nuovo frontend.

Hardware reale: hci0 presente, enabled, non bloccato. Nessun dispositivo paired
inizialmente. Apertura popup e avvio discovery verificati, nessun manager esterno.
Durante il primo test UI a coordinate, l'aggiornamento lista ha spostato il
pulsante stop: un click ha involontariamente avviato un pairing, terminato con
Authentication Failed. Nessuna associazione salvata; paired=0, connected=0,
Powered=true, Discovering=false verificati dopo il test. Il comando scan è stato
spostato sopra la lista per evitare questa instabilità. Nessun forget eseguito.
Connect/disconnect, pairing riuscito e batteria sono verificati con mock;
non erano disponibili periferiche reali adatte a queste prove.

## Validazione

- Suite repository e ShellCheck; migrazione idempotente/rollback (3 test).
- 20 check mock notifiche; 39 check selector audio/Bluetooth.
- Protocollo nativo su bus privato: ownership, capabilities, replacement,
  azioni, resident/transient, critical, timeout, max toast, clear,
  close reasons, reload e collisione (secondo server non sottrae il bus).
- notify-send reale: low/normal/critical, titolo, body, icona locale,
  notifiche multiple; toast e centro verificati visivamente, dismiss e cleanup.
- QML su Sway headless con due output, popup e stack notifiche che segue
  il monitor focused; statistiche, workspace, Ethernet e PipeWire operativi.
- Doctor Quickshell, Sway --validate, systemd-analyze --user verify,
  git diff --check.
- Doctor generale: errori preesistenti Docker Desktop link, Claude e Copilot
  assenti. Nessuna correzione a componenti estranei a questa richiesta.

Il backend resta event-driven; nessun polling di busctl/notify-send/bluetoothctl.

Controllo finale aggiuntivo: adapter ora enumerato come hci2, Powered=true,
Discovering=false, paired=0, connected=0; shell e widget sopravvivono al cambio
adapter senza restart. Nel journal è rimasto un warning nativo isolato di BlueZ
“Operation already in progress” durante stop discovery su hci1; nessuna discovery
lasciata attiva, nessun errore QML o symbol lookup nello stato finale.

File di questa estensione oltre ai componenti sopra elencati:

- `templates/quickshell/services/BluetoothService.qml`
- `templates/quickshell/popups/BluetoothPopup.qml`
- `templates/quickshell/popups/BluetoothDeviceRow.qml`
- `bin/workstation-notifications.py`
- `bin/configure-quickshell.py`
- `bin/workstation-bar.sh`
- `bin/doctor-quickshell.sh`
- `bin/test-quickshell-runtime.py`
- `bin/audit-urls.sh`, `config/sources.env`
- `tests/test-notification-migration.py`
- `tests/test-notification-protocol.py`
- `tests/test-quickshell-notifications.sh`
- `tests/test-quickshell.py`
- `tests/fixtures/quickshell/notifications.qml`
- `tests/fixtures/quickshell/notification-server.qml`
- `tests/fixtures/quickshell/selectors.qml`
- `README.md`, `AUDIT.md`, questo report.

Le altre modifiche Wi-Fi/audio già presenti nel working tree sono preservate.
