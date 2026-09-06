# Selettori Quickshell: verifica del 6 settembre 2026

Implementazione estesa senza sostituire la shell, il wrapper, il servizio o gli
altri moduli. Nessun pacchetto installato e nessun nuovo repository abilitato.
Quickshell 0.2.1 Fedora, Qt 6.11.2. API verificate nei qmltypes dell'RPM e nelle
fonti ufficiali elencate in config/sources.env.

## File

- Wi-Fi: services/network.py esteso, nuovo services/wifi.py; SystemData.qml
  invia comandi senza credenziali su stdin al processo libnm esistente.
- Audio: services/AudioService.qml e popups/AudioPopup.qml estesi.
- Bluetooth: nuovi services/BluetoothService.qml, services/desktop-settings.py,
  popups/BluetoothPopup.qml e popups/BluetoothDeviceRow.qml.
- UI condivisa: nuovo popups/DeviceButton.qml; shell.qml e bar/Bar.qml collegano
  un unico servizio Bluetooth condiviso fra monitor. NetworkPopup.qml esteso.
- Doctor: nuovo bin/doctor-quickshell-hardware.py, bin/doctor-quickshell.sh e
  bin/test-quickshell-runtime.py estesi.
- Test: tests/test-quickshell-wifi.py, tests/test-quickshell-selectors.sh,
  tests/fixtures/quickshell/selectors.qml e SelectorTestBars.qml.
- Documentazione/provenance: README.md, AUDIT.md, config/sources.env,
  bin/audit-urls.sh e questo report.

I path servizi/popup/bar sono relativi a templates/quickshell. Le modifiche sono
state installate anche in ~/.config/quickshell/workstation con il configuratore
managed. Backup V1 in /tmp/quickshell-v1-backup-hxuwbjkh/workstation (temporaneo).
Il manifest resta coerente e la seconda esecuzione ha prodotto file identici.

## Wi-Fi

Nessun dispositivo Wi-Fi reale sulla workstation: NetworkManager espone Ethernet
attiva. Verificato visivamente il popup Ethernet senza controlli Wi-Fi.

Con hardware presente, gli AP arrivano da libnm/D-Bus e segnali notify/AP add/remove.
Deduplica per SSID binario, rete corrente prima e poi segnale decrescente; si mostra
il segnale migliore dei BSSID duplicati mantenendo il target corrente se connesso.
SSID hidden/vuoti rimangono distinti. Supportati adapter multipli e AP rimossi.

Toggle WirelessEnabled asincrono, scansione esplicita con request_scan_async e
limite di 15 secondi per adapter. Attivazione del profilo compatibile salvato con
activate_connection_async; reti aperte nuove con add_and_activate_connection_async.
Stati e fallimenti arrivano da callback e segnali; nessun nmcli periodico.

Nessun campo password o Secret Agent locale. Per reti protette nuove/nascoste si
apre nm-connection-editor --create --type=802-11-wireless e si completano SSID e
sicurezza nell'editor. NetworkManager e il suo agent mantengono i segreti dei
profili salvati. Non vengono stampate eccezioni D-Bus o comandi ricevuti. Il canale
JSON ammette solo campi noti, nessun campo secret. Editor avviato e atteso in modo
asincrono, con stdout/stderr silenziati. nm-connection-editor è già un RPM Fedora.

## Bluetooth

Rilevati BlueZ, adapter hci0 acceso, rfkill sbloccato, zero device noti/associati.
Widget BT visibile e popup reale aperto senza errori. Nessun pairing o forget reale.

API: Bluetooth.adapters/defaultAdapter, adapter.devices, enabled/state/discovering;
device connected/state/paired/bonded/pairing, pair/cancelPair/forget,
batteryAvailable/battery e icon. Il setter connected equivale alle chiamate native
connect/disconnect. Gli stati transitori sono mostrati; Blocked impedisce il toggle.
Le operazioni fallite hanno messaggi generici e timeout senza retry. Nessuna modifica
automatica a trusted. Forget richiede conferma separata e attende stato/rimozione.

Discovery reale avviata dal nuovo servizio e fermata, senza cambiare powered;
verificato Discovering=false al termine. Discovery limitata a 30 secondi, arrestata
alla chiusura del popup proprietario; una sessione preesistente non viene acquisita.

Pairing di base esplicito tramite Associa senza PIN. Pairing autenticato, passkey,
PIN e conferme restano nel tool di sistema: Blueman già installato (RPM Fedora),
altrimenti GNOME Settings se presente; messaggio esplicito se non c'è un frontend.
Nessun agent incompleto o gestione locale di credenziali. Batteria mostrata soltanto
se disponibile e convertita da 0–1 a percentuale. Non verificabile su device reale
in questa sessione; coperta da mock. Nomi al posto dei MAC, icona nativa se presente.

BlueZ gestisce dispositivi/connessione, PipeWire gestisce l'audio delle cuffie:
nessun routing o volume duplicato nel servizio Bluetooth.

## Audio

Graph reale: output HDMI AD107 e USB PCM2902, input USB PCM2902. I candidati sono
nodi audio non stream, associati con PwObjectTracker prima delle letture bound;
filtri media.class Audio/Sink o Audio/Source, direzione isSink, esclusione monitor e
virtuali. Stream applicativi e nodi interni non vengono mostrati.

Selezione con preferredDefaultAudioSink/preferredDefaultAudioSource; UI, check,
slider e mute seguono defaultAudioSink/defaultAudioSource effettivi. Null e rimozione
sono gestiti; un timeout segnala una preferenza non applicata. Hotplug è a eventi.

Test reale tramite gli stessi servizi QML: output cambiato HDMI → USB, input USB
selezionato; volumi output/input temporaneamente 35%/65%, mute separati verificati.
Ripristino verificato dei volumi per canale, mute, default e preferenze iniziali
(compresa l'assenza di un preferred source esplicito). Stato finale: HDMI 98%, USB
output 40%, USB input 100%, tutti non muted, preferenza output HDMI. Nessun audio
riprodotto o microfono registrato durante il test.

Il cambio tra due input fisici non è verificabile con un solo input; selezione,
null, rimozione e nodi Bluetooth sono coperti con mock. Non sono gestiti i profili
A2DP/HFP: sono selezionabili i sink/source già esposti da WirePlumber.

## Test e stato finale

- 11 test Python libnm/mock: hardware assente/presente, dedup/sorting/current,
  hidden/empty, multi-adapter, attivazione salvata e rete aperta, fallback protetto,
  toggle, scan/rate limiting, AP scomparso, fallimenti e assenza di secret nei log.
- 36 assert QML contro backend simulati: radio assente/presente, blocked,
  enabling/disabling, gruppi device, battery, discovery propria/esterna,
  pairing fallito, connect/disconnect/stati, trusted invariato, conferma forget,
  rimozione device/adapter, audio filtri/default/input/output/volume/mute/hotplug.
- Test QML reali e popup popolati con 30 AP simulati su Sway headless a due output.
  Conservati test di workspace, CPU/RAM/temperatura e popup calendario/power.
  WORKSTATION_QUICKSHELL_TEST impedisce mutazioni dei backend reali.
- Popup reali audio, Bluetooth e rete aperti e verificati visivamente sulla sessione.
- Suite repository completa e ShellCheck passati; git diff --check pulito.
- Doctor Quickshell passa. Doctor generale exit 1 soltanto per problemi preesistenti
  Docker Desktop link vendor, Claude assente e Copilot assente.
- Quickshell resta il backend del servizio active/running; Waybar fallback,
  servizio, Sway e altri moduli invariati. Nessun reboot/logout.

Limiti delle prove: nessun Wi-Fi reale, nessun device Bluetooth paired/connected
con cui verificare pairing/batteria o connessione; hotplug fisico non eseguito.
Questi casi sono coperti da mock, non certificati sull'hardware assente.
