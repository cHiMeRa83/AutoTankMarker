# 🛡️ AutoTankMarker (ATM)
> Das ultimative WotLK 3.3.5a UI- & Utility-Addon für Tanks & Heiler.

[![WoW Patch](https://img.shields.io/badge/WoW-3.3.5a-blue.svg)]()
[![Version](https://img.shields.io/badge/Version-1.62-green.svg)]()

📥 **[Download Latest Release](https://github.com/cHiMeRa83/AutoTankMarker/releases/latest)**

---

### ✨ Hauptfunktionen im Überblick

* 🎯 **Automatische Tank-Markierung & Fokus:** Erkennt den Tank in Dungeons/Raids automatisch über Rollen oder Auren und setzt dein gewähltes Wunschsymbol sowie das Fokus-Ziel (`FocusUnit`).
* 📊 **Live Tank-Aggro Prozentleiste & Native Threat-Schnittstelle:**
  * **Echtzeit-Bedrohung:** Zeigt im Kampf exakt an, wie viel % Aggro der Tank auf sein aktuelles Ziel hat.
  * **Dynamische Farbkodierung:** Wechselt fließend von 🟢 **Grün** (Sicher) zu 🟡 **Gelb** (Achtung) und 🔴 **Rot** (Kritisch).
  * ⚙️ **Automatisches Threat-Enable:** Aktiviert beim Laden automatisch `threatShowNumeric`, um das Aggro-Tracking der WotLK-Engine nativ für alle Gruppenmitglieder und Namensschilder bereitzustellen.
* ⚠️ **Aggro-Alarm:** Optischer & akustischer Warnbalken bei Heiler-Aggro inklusive automatischem Gruppen-/Raid-Ruf in Deutsch oder Englisch.
* 💬 **Automatischer Tank-Whisper:** Benachrichtigt den Tank direkt, wenn du OOM gehst (< 15% Mana) oder dich zum Trinken hinsetzt.
* 🚑 **Tank-HP & Tod-Warnungen:** Warnt dich sofort mit prominenten Bildschirm-Meldungen und Sounds, wenn der Tank unter 25% Leben fällt oder stirbt.
* 🛡️ **Defensiv-CD Tracker:** Erkennt und meldet große Tank-Überlebensfähigkeiten (*Schildwall, Letztes Gefecht, Göttlicher Schutz, Eisige Gegenwehr etc.*).
* ⚙️ **In-Game Einstellungsmenü (`/atm config`):**
  * **Grafische Verwaltung:** Schalter für alle Features, Sprachauswahl (DE/EN) und Symbol-Dropdown.
  * 🔓 **Aggro-Leiste freigeben:** Per Checkbox die Prozentleiste zum freien Verschieben einblenden oder Position per Klick zurücksetzen.
  * 🔘 **Testmodus-Button:** Simulationstest aller Alarme und Leisten direkt per Button im Menü starten.

---

### ⌨️ Slash-Befehle

| Befehl | Funktion |
| :--- | :--- |
| `/atm` oder `/autotank` | Führt die Tank-Suche und das Markieren sofort manuell aus. |
| `/atm config` oder `/atm opt` | Öffnet das Einstellungsmenü im Spiel. |
| `/atm test` | Startet den Simulationstest aller Warnbalken und der Aggro-Leiste. |
| `/atm skull` / `/atm cross` | Wechselt das Markierungssymbol direkt per Befehl auf Totenkopf oder Kreuz. |

---

### 📦 Installation
1. Lade die neueste Version über den Download-Link oben herunter.
2. Entpacke die `.zip`-Datei in deinen WoW-Addon-Ordner: `World of Warcraft/Interface/AddOns/`
3. Stelle sicher, dass der Pfad wie folgt aussieht: `Interface/AddOns/AutoTankMarker/AutoTankMarker.lua`
4. Starte das Spiel neu oder gib im Spiel `/reload` ein.

---

### 📝 Changelog (v1.62)
* **Neu:** Automatisches Aktivieren der internen Client-Variable `SetCVar("threatShowNumeric", 1)` beim Ladevorgang für lückenlose Aggro-Synchronisation in Instanzen & Raids.
