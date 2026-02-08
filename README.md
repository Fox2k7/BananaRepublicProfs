# BananaRepublicProfs

Ein Gilden-Berufe-Addon für Turtle WoW / Vanilla 1.12, das automatisch alle Rezepte und Berufe von Gildenmitgliedern synchronisiert.

## Features

- 🔄 **Automatische Synchronisation**: Wenn du einen Beruf öffnest, werden deine Rezepte automatisch an die Gilde gesendet
- 🔍 **Durchsuchbare Datenbank**: Suche nach jedem Rezept in deiner Gilde
- 📊 **Filter nach Beruf**: Zeige nur Verzauberungen, Schmiedekunst, etc.
- 💬 **Direkter Kontakt**: Klicke auf ein Rezept und whisper den Crafter direkt
- 📝 **Materialien-Anzeige**: Sieh alle benötigten Materialien für jedes Rezept
- 🍌 **Banana Republic approved!**

## Installation

### Mit Turtle WoW Addon Manager
1. Öffne den Turtle WoW Addon Manager
2. Suche nach "BananaRepublicProfs"
3. Klicke auf "Install"
4. Fertig!

### Manuelle Installation
1. Lade die neueste Version von [Releases](https://github.com/DEIN_USERNAME/BananaRepublicProfs/releases) herunter
2. Entpacke den Ordner nach `World of Warcraft/Interface/AddOns/`
3. Starte WoW neu oder tippe `/reload`

## Verwendung

### Befehle
- `/brp show` - Öffnet/schließt das Hauptfenster
- `/brp scan` - Scannt den aktuell geöffneten Beruf manuell
- `/brp send` - Sendet alle gespeicherten Berufe an die Gilde

### Automatischer Scan
Das Addon scannt automatisch, wenn du einen Beruf öffnest (Verzauberkunst, Schmiedekunst, etc.)

### Rezepte finden
1. Tippe `/brp show`
2. Nutze das Suchfeld um nach Rezepten zu suchen (z.B. "Crusader")
3. Nutze das Dropdown-Menü um nach Beruf zu filtern
4. Klicke auf ein Rezept um Details und Materialien zu sehen
5. Klicke "Whisper" um den Crafter direkt anzuschreiben

## Voraussetzungen

- ⚠️ **Beide Spieler müssen in derselben Gilde sein**
- ⚠️ **Beide Spieler müssen das Addon installiert haben**
- Die Daten werden über den Guild-Chat-Channel synchronisiert

## Technische Details

- **Kompatibilität**: Turtle WoW / Vanilla 1.12
- **Lua Version**: 5.0 kompatibel
- **Speicherung**: SavedVariables (BRPDB)
- **Protokoll**: Chunked guild messages mit automatischem Throttling

## Changelog

### v0.6 (aktuell)
- ✅ Manuelles Scrolling (keine FauxScrollFrame-Abhängigkeit)
- ✅ Vanilla 1.12 kompatibel (SetWidth/SetHeight statt SetSize)
- ✅ Stabiles UI ohne Crashes
- ✅ Mousewheel-Support überall

### v0.5
- Erste stabile Version mit manuellem Scrolling

### v0.3-0.4
- Experimentelle FauxScrollFrame-Versionen (deprecated)

## Support

Bei Problemen oder Feature-Requests öffne bitte ein [Issue auf GitHub](https://github.com/DEIN_USERNAME/BananaRepublicProfs/issues).

## Lizenz

Dieses Addon ist Open Source und frei verwendbar.

## Credits

Entwickelt für die Banana Republic Gilde auf Turtle WoW 🍌
