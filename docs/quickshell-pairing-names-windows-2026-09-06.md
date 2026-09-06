# Pairing, nomi Bluetooth e finestre Sway

I tentativi da Quickshell riportavano Authentication Failed, mentre
blueman-applet.service non era attivo; aprendo il gestore si avviava anche
l'agente di autenticazione ufficiale. Quickshell 0.2.1 chiama Pair su BlueZ,
ma non espone un agent per rispondere alle challenge. BlueZ usa l'agente default
quando il chiamante non ne registra uno proprio.

`services/desktop-settings.py ensure-agent` attiva org.blueman.Applet via D-Bus,
verifica il plugin AuthAgent e l'endpoint org.bluez.Agent1 del relativo processo.
`BluetoothService.qml` attende questa preparazione prima del Pair nativo,
controllando ancora presenza device e stato radio. Non apre il manager.
PIN/conferme vengono gestiti dal codice ufficiale Blueman, via notifiche/azioni
o dialoghi di sistema; non è un'implementazione di autenticazione in QML.
Agente mancante/errore mantiene il fallback esplicito. Attivazione singleton;
readiness limitata a questa operazione, nessun polling permanente.

Verifica reale: agente attivo e endpoint rilevato, nessun blueman-manager aperto.
MX Anywhere 3 resta Paired=true, Connected=true, Trusted=true. Non è stato
rimosso né riassociato per i test: il pairing completo di un nuovo dispositivo
resta da confermare nel normale uso. Il controller USB ha inoltre mostrato
precedentemente timeout HCI/reset, separati dal problema dell'agente.

Il launcher del manager trasferisce gtk-theme/color-scheme dalle preferenze
GNOME solo all'environment figlio. Tema GTK effettivo verificato: Adwaita-dark;
nessuna variabile globale modificata.

Nomi: Alias e deviceName vengono valutati separatamente; un alias MAC non
nasconde più un nome valido. Se entrambi mancano, il popup dice Nome non
disponibile e mostra l'indirizzo soltanto aprendo i dettagli. Test coprono nome
che arriva successivamente e alias personale. I dispositivi anonimi rilevati
non possono essere identificati con certezza dal solo indirizzo.

Sway: rimossa la regola corrente 65-cliamp.conf; launcher cliamp-widget portato
nel repository e aggiornato per avviare/focalizzare la finestra senza scratchpad.
Restano regole custom floating per PolicyKit, NetworkManager, pavucontrol,
Blueman e GNOME Settings. Configurazione corrente validata e ricaricata;
nessuna finestra Cliamp era aperta da convertire. La migrazione idempotente
configure-sway-windows.py è inclusa nel modulo Sway. Backup una sola volta,
fuori dalle directory incluse da Sway. Regole personali ambigue preservate.

Test: suite repository completa, 44 check selector, test helper autenticazione
(mock D-Bus senza Pair/Connect/Discovery), tema senza effetti sull'environment,
migrazione finestre idempotente e preservazione file personali, rendering popup,
ShellCheck launcher, doctor Quickshell e git diff --check.
