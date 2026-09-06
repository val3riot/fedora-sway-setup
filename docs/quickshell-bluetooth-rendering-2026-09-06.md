# Correzione rendering popup Bluetooth

L'artefatto segnalato è stato riprodotto su Sway headless con gli stessi
componenti della workstation, senza coinvolgere hardware reale. Inserendo device
simulati, BluetoothPopup passava da 161 a 561 px; il buffer precedente veniva
stirato verticalmente, mostrando titolo e pulsanti deformati. Non comparivano
errori QML: la sola validazione del parser non rilevava il difetto.

BluetoothPopup ora mantiene una geometria di 320×420 px (altezza ridotta su
output piccoli), indipendente da discovery, lista device, radio e messaggi.
La lista e gli errori scorrono in un viewport interno con larghezza/altezza
esplicite. Titolo, ricerca, toggle e Chiudi rimangono in posizioni stabili.
Non sono cambiati il renderer globale, Wayland, BlueZ o gli altri popup.

Aggiunti `tests/test-bluetooth-popup.py` e fixture
`tests/fixtures/quickshell/bluetooth-popup.qml`, eseguiti dalla suite selector
quando Sway, grim e Pillow sono disponibili. Il test confronta i pixel del
titolo nelle sequenze lista vuota/piena/vuota, OFF/ON, messaggio e nuova ricerca;
controlla geometria costante e che i nuovi contenuti vengano effettivamente
renderizzati. Tolleranza di due livelli RGB per l'antialiasing. Il codice
precedente fallisce il test; la correzione lo supera.

Verifica reale: popup e discovery con device trovato mostrati senza deformazioni.
La prova di spegnimento reale non è stata completata: durante lo stop discovery
il kernel ha registrato un problema separato dell'adapter TP-Link USB Realtek
RTL8761BU, con `command 0x200c tx timeout`, `Unable to disable scanning: -110`
e reset USB. L'adapter scompare da BlueZ e viene nuovamente enumerato (hci2 →
hci0). Questo problema del controller/driver non viene dichiarato risolto dalla
correzione QML; non sono state applicate modifiche speculative a firmware,
autosuspend o configurazione globale. La barra è stata riavviata per rilasciare
la discovery di test. Nessun pairing o forget eseguito in questa correzione.

Il servizio ripulisce inoltre ownership e timer della scansione quando il suo
adapter viene rimosso, senza retry sul vecchio percorso D-Bus; coperto da mock.
