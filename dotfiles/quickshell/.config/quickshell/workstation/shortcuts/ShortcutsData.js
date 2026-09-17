.pragma library

const categories = [
    {
        category: "Navigazione & Terminale",
        items: [
            { keys: "Super + Invio", desc: "Apre il terminale Kitty" },
            { keys: "Super + D", desc: "Launcher applicazioni (Quickshell)" },
            { keys: "Super + G", desc: "Guida scorciatoie da tastiera" },
            { keys: "Super + V", desc: "Storico appunti volatile (solo RAM)" }
        ]
    },
    {
        category: "Finestre & Tiling",
        items: [
            { keys: "Super + Shift + Q", desc: "Chiude la finestra attiva" },
            { keys: "Super + Shift + Spazio", desc: "Alterna modalità tiling e floating" },
            { keys: "Super + Spazio", desc: "Alterna focus tra tiling e floating" },
            { keys: "Super + F", desc: "Attiva / disattiva schermo intero" },
            { keys: "Super + B", desc: "Imposta suddivisione orizzontale (splith)" },
            { keys: "Super + Shift + V", desc: "Imposta suddivisione verticale (splitv)" },
            { keys: "Super + H / J / K / L", desc: "Sposta il focus tra le finestre" },
            { keys: "Super + Frecce", desc: "Sposta il focus tra le finestre" },
            { keys: "Super + Shift + H/J/K/L", desc: "Sposta la finestra attiva" },
            { keys: "Super + 1…10", desc: "Passa al workspace 1…10" },
            { keys: "Super + Shift + 1…10", desc: "Sposta la finestra al workspace 1…10" }
        ]
    },
    {
        category: "Sessione & Sistema",
        items: [
            { keys: "Super + Shift + C", desc: "Ricarica configurazione Sway" },
            { keys: "Super + Shift + E", desc: "Menu di uscita / spegnimento" },
            { keys: "Super + Shift + X", desc: "Blocca lo schermo (swaylock)" },
            { keys: "Print", desc: "Cattura area selezionata (appunti e file)" },
            { keys: "Shift + Print", desc: "Cattura schermo intero (appunti e file)" },
            { keys: "Super + Print", desc: "Cattura finestra attiva (appunti e file)" }
        ]
    },
    {
        category: "Controlli Multimediali & OSD",
        items: [
            { keys: "Tasti Volume", desc: "Regola o disattiva il volume audio" },
            { keys: "Tasti Luminosità", desc: "Regola la luminosità dello schermo" }
        ]
    }
];

function allItems() {
    const list = [];
    for (const cat of categories) {
        for (const item of cat.items) {
            list.push({
                category: cat.category,
                keys: item.keys,
                desc: item.desc,
                name: item.keys + " " + item.desc + " " + cat.category
            });
        }
    }
    return list;
}
