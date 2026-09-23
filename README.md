# 🛡️ AutoTankMarker (ATM)

![Version](https://img.shields.io/badge/Version-v1.7-blue.svg)
![WoW Version](https://img.shields.io/badge/WoW-3.3.5a-orange.svg)

> **Ein unverzichtbares Utility-Tool für Heiler in World of Warcraft: Wrath of the Lich King (Patch 3.3.5a)**

[![Download Latest Release](https://img.shields.io/badge/📥_Download-Neueste_Version_(v1.7)-brightgreen?style=for-the-badge&logo=github)](https://github.com/cHiMeRa83/AutoTankMarker/releases/latest)

---

AutoTankMarker (ATM) erleichtert Heilern die Arbeit in Dungeons und Raids enorm. Es identifiziert automatisch den Tank deiner Gruppe, markiert ihn mit einem Zielsymbol, überwacht Bedrohung (Aggro), zeigt aktive Defensiv-Cooldowns, Tank-Wechsel und Interrupts an und informiert über den Status des Tanks sowie dein eigenes Mana.

---

## ✨ Hauptfunktionen

* 🎯 **Automatische Tank-Erkennung & Markierung:**
  * Erkennt Tanks anhand von Gruppenrollen, Klassen und aktiven Haltungen/Auren (*Verteidigungshaltung, Zorn des Gerechten, Bärenform, Frostpräsenz*).
  * Markiert den Tank automatisch mit einem wählbaren Zielsymbol (Standard: Blaues Quadrat).

* 📊 **Dynamische Tank-Aggro % Leiste:**
  * Zeigt die prozentuale Bedrohung des Tanks in Echtzeit an (inklusive intelligentem Dungeon-Fallback).
  * Automatische Bedrohungs-Schnittstelle (`SetCVar("threatShowNumeric", 1)` beim Start).

* 🛡️ **Intelligenter CD-Monitor & Def-CD Tracker:**
  * **CD-Monitor Leiste:** Eine separate, verschiebbare Statusleiste, die aktive Defensiv-CDs des Tanks mit Ablauf-Timer visualisiert.
  * **Bildschirm-Banner & Sounds:** Warnt dich sofort, wenn der Tank große Schutz-Fähigkeiten zündet (*Schildwall, Letztes Gefecht, Göttlicher Schutz, Baumrinde etc.*).

* 🔄 **Tank-Wechsel-Erkennung (Taunt-Swap):**
  * Erkennt automatisch, wenn ein Tank den Spott weitergibt, und informiert dich visuell über den Wechsel.

* ⚡ **Interrupt- & CC-Tracker:**
  * Zeigt an, welche Zauber in der Gruppe erfolgreich unterbrochen wurden.

* 🚨 **Heiler-Aggro & Status-Warnungen:**
  * **Heiler-Aggro:** Schlägt Alarm (Sound & Banner) und sendet automatische Warnungen in den Chat, wenn Gegner dich angreifen.
  * **Tank-Gesundheit:** Warnung bei kritischem Leben (< 25 %) und Audiosignal bei Tank-Tod.
  * **Mana & Trinken:** Automatischer Flüstertext an den Tank bei knappem Mana (< 15 %) oder wenn du trinkst.

---

## 🛠️ Befehle & Bedienung

| Befehl | Beschreibung |
| :--- | :--- |
| `/atm` / `/autotank` | Führt eine manuelle Tank-Suche aus und markiert den Tank. |
| `/atm config` | Öffnet das grafische Einstellungsmenü. |
| `/atm test` | Startet den Testmodus (simuliert Banner, Aggro-Leiste, CD-Monitor, Taunt-Swaps & Sounds). |

---

## ⚙️ Einstellungen (Interface-Menü)

Über `/atm config` kannst du alle Optionen deinen Wünschen anpassen:
* Checkboxen für alle Warnmeldungen, den CD-Monitor, Taunt-Swaps und den Interrupt-Tracker.
* Freigabe und Positionierung der Aggro- und CD-Leisten per Maus (`Aggro-Leiste freigeben` + `Position zurücksetzen`).
* Auswahl des Zielsymbols (Stern, Kreis, Diamant, Dreieck, Mond, Quadrat, Kreuz, Totenkopf).
* Umschaltung der Sprache für Chat-Meldungen & Warnungen (Deutsch / Englisch).

---

## 💻 Installation

1. [Klicke hier, um Version 1.7 herunterzuladen](https://github.com/cHiMeRa83/AutoTankMarker/releases/latest).
2. Entpacke den heruntergeladenen Ordner in dein WoW-Verzeichnis:
   `World of Warcraft\Interface\AddOns\`
3. Stelle sicher, dass der Ordnerpfad wie folgt aussieht:
   `World of Warcraft\Interface\AddOns\AutoTankMarker\AutoTankMarker.lua`
4. Starte World of Warcraft neu oder gib `/reload` im Spiel ein.

---

## 📝 Kompatibilität

* **Spielversion:** World of Warcraft: Wrath of the Lich King (3.3.5a)
* **Sprachen:** Deutsch (`DE`), Englisch (`EN`)
