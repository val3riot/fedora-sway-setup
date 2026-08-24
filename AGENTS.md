# Istruzioni per agenti

1. Prima di operare, leggere `~/.agent/AGENTS.md` e `~/.agent/LOCAL_NOTES.md`.
2. Considerare `~/.agent/AGENTS.md` contesto macchina gestito dal setup: non modificarlo direttamente.
3. Rendere persistenti gli aggiornamenti in `modules/05-agent-context.sh` o `templates/agent-conventions.md`.
4. Dopo modifiche che cambiano macchina, percorsi, software o convenzioni, rigenerare il contesto con:

   ```bash
   ROOT_DIR="$PWD" PROFILE=base DESKTOP_ENV="${DESKTOP_ENV:-none}" bash modules/05-agent-context.sh
   ```

5. Non sovrascrivere `~/.agent/LOCAL_NOTES.md`; modificarlo solo su richiesta esplicita dell'utente.
