# 🛡️ AutoTankMarker (ATM)

![Version](https://img.shields.io/badge/Version-v1.75-blue.svg)
![WoW Version](https://img.shields.io/badge/WoW-3.3.5a-orange.svg)

> **Ein unverzichtbares Utility-Tool für Heiler in World of Warcraft: Wrath of the Lich King (Patch 3.3.5a)**

[![Download Latest Release](https://img.shields.io/badge/📥_Download-Neueste_Version_(v1.75)-brightgreen?style=for-the-badge&logo=github)](https://github.com/cHiMeRa83/AutoTankMarker/releases/latest)

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

* 💾 **Permanente Einstellungsspeicherung:**
  * Alle Konfigurationen, Slider-Werte, Fensterpositionen und Sound-Auswahlen werden dank sauberer `SavedVariables`-Einbindung dauerhaft im WTF-Ordner gespeichert und überstehen jeden `/reload` fehlerfrei.

---

## 🚀 Neu in Version v1.75 (Changelog)

* 💾 **Permanente Speicherung:** Die Konfigurationsvariablen wurden über `SavedVariables` angebunden, sodass Einstellungen und Layout-Positionen nicht mehr zurückgesetzt werden.
* ~~🎵 **Custom Sound Integration:** Volle Unterstützung für eigene `.wav`-Dateien (*Ack, Fart, Among Us*) via `PlaySoundFile` für Alarme und Interrupts.~~
* 🛡️ **Optimierte Def-CD-Anzeige:** Tank-Defensiv-CDs im Dungeon und Raid heben sich jetzt sofort durch einen kräftigen, gut lesbaren Gold/Gelb-Ton (`>> TANK CD: [Name] <<`) ab.
* 📏 **Erweiterte UI-Größenanpassung:** Neben der Breite lassen sich jetzt auch die **Höhen** für die Tank-Aggro-Ampelleiste und den CD-Monitor direkt über neue Schieberegler im Optionsmenü individuell einstellen.
* 🎨 **UI & Layout Optimierungen:** Die Dropdowns und Menüelemente im Einstellungsfenster wurden übersichtlich aufgeteilt und perfekt ausgerichtet (kein Überlappen mehr).
* 👤 **Entwickler-Info:** Offizieller Entwickler-Credit für **cHiMeRa83** (`v1.75 ©cHiMeRa83`) im Titel des Einstellungsfensters eingepflegt.

---

## 🛠️ Befehle & Bedienung

| Befehl | Beschreibung |
| :--- | :--- |
| `/atm` / `/autotank` | Führt eine manuelle Tank-Suche aus und markiert den Tank. |
| `/atm config` | Öffnet das grafische Einstellungsmenü. |
| `/atm test` | Startet den Testmodus (simuliert Banner, Aggro-Leiste, CD-Monitor, Taunt-Swaps & Sounds). |
| `/atm pos <Grad>` | Setzt den Minimap-Button alternativ per Chat auf einen bestimmten Winkel (0–360). |

---

## ⚙️ Einstellungen (Interface-Menü)

Über `/atm config` kannst du alle Optionen deinen Wünschen anpassen:
* Checkboxen für alle Warnmeldungen, den CD-Monitor, Taunt-Swaps und den Interrupt-Tracker.
* Stufenlose Regler für Breiten (bis zu 500px), Höhen, Schriftgröße und die **Minimap-Position**.
* Separate Tonauswahl für eigene Aggro, verlorene Tank-Aggro und erfolgreiche Interrupts.
* Freigabe und Positionierung **aller Elemente** (Aggro-Leiste, CD-Monitor und Warnbalken) per Maus (*"Alle Elemente verschiebbar machen"* + *"Positionen zurücksetzen"*).
* Auswahl des Zielsymbols (Stern, Kreis, Diamant, Dreieck, Mond, Quadrat, Kreuz, Totenkopf).
* Umschaltung der Sprache für Chat-Meldungen & Warnungen (Deutsch / Englisch).

---

## 💻 Installation

1. [Klicke hier, um Version v1.75 herunterzuladen](https://github.com/cHiMeRa83/AutoTankMarker/releases/latest).
2. Entpacke den heruntergeladenen Ordner in dein WoW-Verzeichnis:
   `World of Warcraft\Interface\AddOns\`
3. Stelle sicher, dass der Ordnerpfad wie folgt aussieht:
   `World of Warcraft\Interface\AddOns\AutoTankMarker\AutoTankMarker.lua`
4. Starte World of Warcraft neu oder gib `/reload` im Spiel ein.

---

## 📝 Kompatibilität

* **Spielversion:** World of Warcraft: Wrath of the Lich King (3.3.5a)
* **Sprachen:** Deutsch (`DE`), Englisch (`EN`)
