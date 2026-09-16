# Migrazione da fedora-workstation-setup a fedora-sway-setup

Questo documento registra la motivazione e la struttura della separazione architetturale del progetto originale `fedora-workstation-setup` in due repository specializzati e indipendenti.

---

## 1. Motivazione

Dall'audit approfondito documentato in `docs/history/SETUP_SCOPE_REPORT.md` è emerso un consistente fenomeno di **scope creep**:
- L'installazione di un ambiente desktop Wayland/Sway finiva per installare e configurare complessi stack di sviluppo (SDKMAN, Java, Node, Python Conda, TeX Live ~1.5 GB), container (Docker CE rootless), hypervisor (KVM/libvirt/Vagrant), agenti AI proprietari (Codex, Claude, Copilot) e applicazioni personali (Discord, Obsidian, Thunderbird).
- Lo script `doctor.sh` richiedeva oltre 21 secondi per l'esecuzione perché eseguiva test di runtime headless completi e controllava decine di strumenti esterni, segnalando errori per strumenti opzionali non installati dall'utente.

---

## 2. Separazione dei Repository

Il progetto è stato suddiviso in due entità distinte:

```
1. fedora-sway-setup (questo repository)
   → Obiettivo: "Rendo Fedora il mio desktop Sway completo"
   → Ambito: Compositor Sway, Quickshell, Greetd, Kitty, Zsh, GNU Stow dotfiles,
     PipeWire, BlueZ, NetworkManager, portali, temi e sfondi.
   → Zero dipendenze da container, SDK, hypervisor o assistenti AI.

2. workstation-tools (repository sibling: ~/Progetti/personali/workstation-tools)
   → Obiettivo: "Installo strumenti opzionali sopra quella workstation"
   → Ambito: Profili modulari espliciti (--dev, --infra, --agents, --apps, --media).
   → Nessun profilo predefinito: nulla viene installato senza richiesta esplicita.
```

---

## 3. Impatto sulla Macchina Locale

La migrazione architetturale interessa esclusivamente il codice dei repository e il comportamento delle future installazioni.
Nessun software preesistente è stato rimosso o disinstallato dalla workstation corrente durante questa transizione.
