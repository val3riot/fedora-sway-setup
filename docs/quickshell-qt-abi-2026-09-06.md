# Diagnosi workstation Fedora 44, 6 settembre 2026

Causa verificata: Quickshell Fedora ricompilato il 31 agosto 2026 per Qt più
recente, installato dalla transazione DNF 21 senza aggiornare Qt 6.11.1.
Categoria A/C: disallineamento fra applicazione e runtime; nessun duplicato RPM.
`dnf repoquery --installed --info` attribuisce tutti questi pacchetti a `updates`.

| Pacchetto | Installato prima | Disponibile in updates |
| --- | --- | --- |
| quickshell (x86_64) | 0.2.1^git20260209.dacfa9d-5.fc44 | identico |
| qt6-qtbase, qt6-qtbase-gui (x86_64) | 6.11.1-1.fc44 | 6.11.2-2.fc44 |
| qt6-qtdeclarative (x86_64) | 6.11.1-3.fc44 | 6.11.2-1.fc44 |
| qt6-qtwayland, qt6-qtsvg (x86_64) | 6.11.1-1.fc44 | 6.11.2-1.fc44 |

Anche gli altri Qt installati sono 6.11.1: filesystem, qtbase-common,
qtpdf, qtpositioning, qtserialport, qttranslations, qtwebchannel,
qtwebengine, qtwebview. qtbase-common e qttranslations sono noarch, gli altri
x86_64. Nessun Qt di una minor precedente rilevato.

`rpm -V` è pulito per Quickshell, qtbase, qtbase-gui, qtdeclarative e qtwayland.
Le dipendenze Qt dirette risolvono ai pacchetti qtbase, qtbase-gui,
qtdeclarative e qtsvg; qtwayland è anche una dipendenza condizionale per Qt <6.10.
Con Qt 6.11 libQt6WaylandClient appartiene a qtbase-gui.

`objdump -T /usr/bin/quickshell` richiede:

```
_ZN23QUntypedPropertyBindingC1EP23QPropertyBindingPrivate @ Qt_6
```

`/usr/lib64/libQt6Core.so.6.11.1` esporta lo stesso nome come
`Qt_6.11_PRIVATE_API`. Il nuovo RPM Fedora qt6-qtbase-6.11.2-2.fc44,
scaricato con DNF e con firma/digest verificati tramite rpmkeys, lo esporta
come `Qt_6`. Non è un simbolo assente in assoluto: è incompatibile la versione.
Le dipendenze RPM Qt_6 / Qt_6.11_PRIVATE_API non impediscono questo mismatch.

Tutte le librerie Qt di `ldd` risolvono da /lib64 a /usr/lib64 e sono Fedora.
Nessuna libQt6Core trovata in ~/Tools, /usr/local, /opt o nelle directory
Flatpak locali. Nessun LD_LIBRARY_PATH, LD_PRELOAD, QT_PLUGIN_PATH,
QML2_IMPORT_PATH, QML_IMPORT_PATH o QT_QPA_PLATFORM_PLUGIN_PATH nella shell
o nel manager systemd user. CONDA_SHLVL=0, nessun CONDA_PREFIX.
QT_QPA_PLATFORM=wayland;xcb viene da ~/.config/environment.d/90-sway.conf.
Gli initializer Miniconda/SDKMAN/NVM sono caricati da env.zsh; non contaminano
il loader Qt. Nessuna modifica dell'environment necessaria.

Transazione esaminata con `dnf --repo=fedora --repo=updates upgrade
--assumeno quickshell 'qt6-*'`: 14 aggiornamenti Qt, nessuna rimozione,
nessun downgrade, 135 MiB di download. Nessun distro-sync, reinstall,
Rawhide, COPR o build manuale. La transazione è stata applicata dall'utente con autenticazione sudo: DNF 22,
6 settembre 2026 08:51:06–08:51:11 UTC, stato Ok.

Prima della correzione sia lo standalone sulla configurazione reale sia
`systemd-run --user --wait --pipe --collect /usr/bin/env LD_BIND_NOW=1
/usr/bin/quickshell --version` falliscono con exit 127 e lo stesso simbolo.
Il servizio originale rimane attivo con Waybar (PID iniziale 4250).
Il nuovo doctor rileva il fallimento ABI; la suite repository passa.
Il doctor generale segnala inoltre problemi preesistenti di provenance
Docker Desktop e agenti Claude/Copilot assenti, fuori da questo intervento.

## Verifica dopo aggiornamento

- Qt base/gui 6.11.2-2.fc44; declarative/wayland/svg 6.11.2-1.fc44.
  Quickshell invariato. Tutte le librerie Qt risolvono a /usr/lib64, vendor Fedora.
  Verifica RPM pulita per tutti i sei pacchetti controllati.
- Standalone sulla configurazione reale: `Configuration Loaded`, vivo dopo
  8 secondi, terminato dal test; nessun errore Qt o QML.
- Screenshot della fascia della barra sulla sessione reale: workspace 1–10,
  CPU, RAM, temperatura, rete LAN, volume e clock visibili.
- Test QML headless passato su due output, cambio workspace con activate()
  e dispatch fino al workspace 7, popup audio/rete/calendario/alimentazione.
  Snapshot: CPU 3%, RAM 15%, temperatura 43 °C, rete Connessa,
  PipeWire pronto, volume 98%. Nessuna azione di alimentazione eseguita.
- Fallback reale del servizio verificato con eseguibile temporaneo che restituisce
  127, tramite PATH limitato al servizio in un drop-in runtime. Waybar PID 13543,
  journal: `Quickshell non avviabile: fallback a Waybar.` Drop-in e stub rimossi.
  Il primo tentativo di riavvio immediato è uscito senza processo (compatibile
  con il lock non ancora rilasciato); ripetuto dopo stop e verifica del rilascio
  del lock, il test è passato. Nessuna modifica al meccanismo di fallback.
- Stato finale: servizio active/running, MainPID 13654 (wrapper bash),
  Quickshell figlio PID 13665, nessuna Waybar. Il wrapper deve rimanere padre
  per gestire il fallback. Journal della nuova invocazione senza symbol lookup
  error o errori QML.
- Doctor Quickshell: exit 0, inclusi test QML. Doctor generale: exit 1 solo
  per problemi preesistenti Docker Desktop/Claude/Copilot sopra descritti.
- Suite repository completa passata; git diff --check pulito.

Modifiche dell'intervento: nuovo bin/check-quickshell-runtime.sh, integrazione
in bin/doctor-quickshell.sh e modules/76-quickshell.sh, nuovo test
 tests/test-quickshell-loader.sh, documentazione README e questo report.
Le altre modifiche già presenti nel working tree sono state preservate.
Nessuna modifica a QML, Sway, Waybar, environment utente o wrapper di fallback;
nessun reboot/logout. La visibilità è stata verificata sulla sessione reale;
l'interazione workspace/popup automatizzata è stata provata nello Sway isolato.
La stabilità osservata è quella della verifica corrente, non un test prolungato.
