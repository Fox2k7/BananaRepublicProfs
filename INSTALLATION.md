# BananaRepublicProfs - Minimap Button Installation

## ✅ Was wurde geändert?

### Neue Features:
- **Minimap-Button** hinzugefügt!
- Linksklick öffnet das Addon-Fenster
- Rechtsklick + Ziehen verschiebt den Button

### Neue Dateien:
1. `BananaRepublicProfs.xml` - UI-Definition (NEU)

### Geänderte Dateien:
1. `BananaRepublicProfs.lua` - Minimap-Funktionen hinzugefügt
2. `BananaRepublicProfs.toc` - Version 5.5.0, XML eingebunden

## 📦 Installation:

### WICHTIG: Du brauchst noch die RecipeMaps-Datei!

Die Datei `BananaRepublicProfs_RecipeMaps.lua` war nicht im Upload dabei.
Du musst sie aus deinem bestehenden Addon-Ordner behalten!

### Vollständige Dateiliste:
```
Interface/AddOns/BananaRepublicProfs/
├── BananaRepublicProfs.lua          ← AKTUALISIERT
├── BananaRepublicProfs.toc          ← AKTUALISIERT
├── BananaRepublicProfs.xml          ← NEU
└── BananaRepublicProfs_RecipeMaps.lua  ← MUSST DU BEHALTEN!
```

### Schritt für Schritt:

1. **Backup erstellen!**
   - Kopiere deinen ganzen `BananaRepublicProfs` Ordner woanders hin

2. **Alte Dateien löschen:**
   - Lösche nur: `BananaRepublicProfs.lua` und `BananaRepublicProfs.toc`
   - **BEHALTE:** `BananaRepublicProfs_RecipeMaps.lua`

3. **Neue Dateien einfügen:**
   - Kopiere die 3 neuen Dateien in den Addon-Ordner

4. **WoW neu starten**

5. **Fertig!** Der Minimap-Button sollte jetzt sichtbar sein 🍌

## 🎮 Verwendung:

- **Linksklick** - Fenster öffnen/schließen
- **Rechtsklick + Ziehen** - Button verschieben
- **Hover** - Tooltip mit Hilfe anzeigen

## 🔧 Fehlerbehebung:

**Button erscheint nicht?**
→ Prüfe ob alle 4 Dateien (inkl. RecipeMaps!) im Ordner sind
→ Lösche `WTF/Account/.../SavedVariables/BananaRepublicProfs.lua`
→ Starte WoW neu

**Button ist an falscher Stelle?**
→ Einfach mit Rechtsklick + Ziehen verschieben
→ Position wird automatisch gespeichert

## 📝 Icon anpassen (Optional):

Aktuell verwendet der Button das Standard-Buch-Icon.

Um ein eigenes Icon zu nutzen:
1. Erstelle ein 32x32 TGA-Bild
2. Lege es in den Addon-Ordner
3. Ändere in `BananaRepublicProfs.xml` die Zeilen 23-24

Siehe `README_MINIMAP.md` für Details!

---

**Version:** 5.5.0
**Kompatibel mit:** Vanilla 1.12 / Turtle WoW
