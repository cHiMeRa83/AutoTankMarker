# 🛡️ AutoTankMarker (ATM)

> **Ein unverzichtbares Tool für Heiler in World of Warcraft: Wrath of the Lich King (Patch 3.3.5a)**

AutoTankMarker (ATM) erleichtert Heilern die Arbeit in Dungeons und Raids enorm. Es identifiziert automatisch den Tank deiner Gruppe, markiert ihn mit einem Zielsymbol, überwacht Bedrohung (Aggro), warnt vor verfehlten Spotts, zeigt aktive Defensiv-Cooldowns an und informiert über den Status des Tanks sowie dein eigenes Mana.

---

## ✨ Hauptfunktionen

* 🎯 **Automatische Tank-Erkennung & Markierung:**
  * Erkennt Tanks anhand von Gruppenrollen, Klassen und aktiven Haltungen/Auren (*Verteidigungshaltung, Zorn des Gerechten, Bärenform, Frostpräsenz*).
  * Markiert den Tank automatisch mit einem wählbaren Zielsymbol (Standard: Blaues Quadrat).

* 📊 **Dynamische Tank-Aggro % Leiste:**
  * Zeigt die prozentuale Bedrohung des Tanks in Echtzeit an (mit Farbwechsel: Grün = Sicher, Gelb = Achtung, Rot = Kritisch).
  * Besitzt eine **Dual-Check-Engine**, die auch in Instanzen zuverlässig ohne direktes Mob-Target funktioniert.
  * Frei verschiebbar mit dunklem Design und schwarzer Schriftkontur (`OUTLINE`) für beste Lesbarkeit.

* 🛡️ **Defensiv-CD Tracker:**
  * Informiert dich per Bildschirm-Banner und Sound, wenn der Tank eine große Überlebensfähigkeit zündet (*Schildwall, Letztes Gefecht, Göttlicher Schutz, Unermüdlicher Hüter, Eisige Gegenwehr, Vampirblut, Überlebensinstinkte, Baumrinde*).
  * Erkennt Fähigkeiten verlässlicher über **Spell-IDs** und Sprachabgleiche (`DE` / `EN`).

* ⚠️ **Spott-Fehlschlag Tracker (*Taunt Fail Alert*):**
  * Warnt sofort mit einem Alarmsound und rotem Banner, wenn der Spott des Tanks (*Spott, Hand der Abrechnung, Todesgriff, Dunkler Befehl, Knurren*) verfehlt oder widerstanden wird.

* 🚨 **Heiler-Aggro & Status-Warnungen:**
  * **Heiler-Aggro:** Schlägt Alarm (Sound & Banner) und sendet bei Bedarf eine automatische Warnung an den Gruppen-/Raid-Chat, wenn Gegner dich angreifen.
  * **Tank-Gesundheit:** Warnung bei kritischem Leben (< 25 %) und Audiosignal bei Tank-Tod.
  * **Mana & Trinken:** Automatischer Flüstertext an den Tank, wenn dein Mana knapp ist (< 15 %) oder du gerade trinkst.

---

## 🛠️ Befehle & Bedienung

| Befehl | Beschreibung |
| :--- | :--- |
| `/atm` / `/autotank` | Führt eine manuelle Tank-Suche aus und markiert den Tank. |
| `/atm config` | Öffnet das grafische Einstellungsmenü. |
| `/atm test` | Startet den Testmodus (simuliert Banner, Aggro-Leiste, Sounds & Chat-Meldungen). |

---

## ⚙️ Einstellungen (Interface-Menü)

Über `/atm config` kannst du alle Optionen deinen Wünschen anpassen:
* Checkboxen für alle einzelnen Warnmeldungen (Aggro, Def-CDs, Spott-Fehlschläge, Low-HP, Mana-Whisper etc.).
* Freigabe der Aggro-Leiste zum Ziehen per Maus + Position zurücksetzen.
* Auswahl des Zielsymbols (Stern, Kreis, Diamant, Dreieck, Mond, Quadrat, Kreuz, Totenkopf).
* Umschaltung der Sprache für Chat-Meldungen & Warnungen (Deutsch / Englisch).

---

## 💻 Installation

1. Lade den Ordner `AutoTankMarker` herunter.
2. Entpacke den Ordner in dein WoW-Verzeichnis:
   `World of Warcraft\Interface\AddOns\`
3. Stelle sicher, dass der Ordnerpfad wie folgt aussieht:
   `World of Warcraft\Interface\AddOns\AutoTankMarker\AutoTankMarker.lua`
4. Starte World of Warcraft neu oder gib `/reload` im Spiel ein.

---

## 📝 Kompatibilität

* **Spielversion:** World of Warcraft: Wrath of the Lich King (3.3.5a)
* **Sprachen:** Deutsch (`DE`), Englisch (`EN`)
