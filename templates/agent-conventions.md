
## Convenzioni operative

1. Prima di cambiare il sistema, leggere `config/versions.env`,
   `config/sources.env` e il modulo pertinente in `modules/`.
2. Rendere persistenti le modifiche nel repository del setup; evitare correzioni
   manuali non riproducibili sulla sola macchina.
3. Per software di sistema preferire, nell'ordine: repository Fedora ufficiali;
   repository RPM ufficiale del vendor con verifica GPG; Flatpak Flathub
   documentato. Non usare COPR o script `curl | sh` senza consenso esplicito.
4. Centralizzare URL in `config/sources.env` e versioni/checksum in
   `config/versions.env`. Verificare gli
   artefatti statici prima dell'esecuzione e non disabilitare TLS o controlli GPG.
5. Usare DNF per RPM, Flatpak `--user` per applicazioni desktop e i runtime già
   predisposti: SDKMAN per Java/Maven/Gradle, NVM per Node e Miniconda per Python.
6. Installare strumenti utente in `~/.local/bin` o nella directory Tools; non
   scrivere in `/usr/local` se non è strettamente necessario e documentato.
7. Non eseguire l'intero setup come root. Usare `sudo` soltanto per pacchetti,
   servizi systemd e configurazioni realmente di sistema.
8. Conservare progetti e checkout nella gerarchia Progetti. Non archiviare
   credenziali, token o chiavi private nel repository o in questa directory.
9. Prima della consegna eseguire `./bin/test.sh`; per diagnosi usare
   `./bin/doctor.sh`, e per la provenienza `./bin/provenance-audit.sh`.
10. Preservare file e modifiche dell'utente. I file dichiarati “gestiti” dal
    setup possono essere rigenerati; `LOCAL_NOTES.md` non deve essere sovrascritto.

## Note per componenti specifici

- Docker opera preferibilmente in modalità rootless; usare `docker-runtime` per
  passare consapevolmente tra rootless e Docker Desktop.
- Le VM usano `qemu:///system`, rete libvirt `default`, dischi QCOW2 e ISO locali.
- Tailscale viene installato e avviato dal setup, ma il login alla tailnet resta
  un'azione esplicita dell'utente.
- Identità Git e alias SSH si aggiungono con `bin/add-git-identity.sh`; non
  sostituire OpenSSH di sistema e non inventare configurazioni globali condivise.
