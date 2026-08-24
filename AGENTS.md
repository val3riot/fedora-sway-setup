# Istruzioni per agenti

1. Prima di operare, leggere `~/.agent/AGENTS.md` e `~/.agent/LOCAL_NOTES.md`.
2. Considerare `~/.agent/AGENTS.md` contesto macchina gestito dal setup: non modificarlo direttamente.
3. Rendere persistenti gli aggiornamenti in `modules/05-agent-context.sh` o `templates/agent-conventions.md`.
4. Dopo ogni modifica strutturale al repository, inclusi cambiamenti a macchina,
   percorsi, software, interfacce o convenzioni, aggiornare le fonti del contesto
   e rigenerare i file in `~/.agent` con:

   ```bash
   ROOT_DIR="$PWD" PROFILE=base DESKTOP_ENV="${DESKTOP_ENV:-none}" bash modules/05-agent-context.sh
   ```

5. Non sovrascrivere `~/.agent/LOCAL_NOTES.md`; modificarlo solo su richiesta esplicita dell'utente.
