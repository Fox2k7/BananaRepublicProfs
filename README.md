# BananaRepublicProfs 🍌

**Guild profession recipe database with sharing and search functionality for Vanilla WoW / Turtle WoW**

[![Version](https://img.shields.io/badge/version-1.0.0-yellow.svg)](https://github.com/yourusername/BananaRepublicProfs/releases)
[![WoW](https://img.shields.io/badge/wow-1.12-blue.svg)](https://www.turtle-wow.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

![BananaRepublicProfs UI](screenshots/main-ui.png)

## 📖 Overview

BananaRepublicProfs is a comprehensive addon for managing and sharing profession recipes within your guild. Scan your professions, share them with guildmates, and quickly find who can craft what you need!

**Perfect for guilds on Turtle WoW's Tel'Abim server!**

## ✨ Features

### 🔍 Smart Recipe Search
- **1,513 recipes** across 7 professions
- Real-time search as you type
- Filter by profession (Alchemy, Blacksmithing, Enchanting, Engineering, Jewelcrafting, Leatherworking, Tailoring)
- Sub-category filters for each profession
- See who can craft each recipe

### 👥 Guild Sharing
- Automatically share your recipes with the guild
- See all guild members' professions in one place
- Online/Offline status indicators
- Smart synchronization (no spam!)
- Optimized network traffic (50% fewer chunks than v0.x)

### 💬 Direct Communication
- Whisper crafters directly from the UI
- Copy recipe links to chat
- Multi-crafter support (choose from multiple people who can craft)
- "Who can craft this?" functionality

### 🗺️ Minimap Button
- Clickable minimap button with custom Banana Republic logo
- Left-click: Open/close UI
- Right-click + drag: Move button position
- Beautiful round design with golden border

### ⚡ Performance & Reliability
- **Automatic scanning** when opening profession windows
- **Retry mechanism** ensures scans never fail
- **Intelligent chunk system** for efficient network usage
- **Clean debug output** (toggle with `/brp debug`)
- **Bank scanning** to track your materials

### 🎨 Modern UI
- Dark, readable interface
- Scrollable lists with 20+ entries per page
- Detailed recipe popups with reagent information
- Professional design with version info and copyright

## 📦 Installation

### Automatic (Recommended)
1. Download the [latest release](https://github.com/yourusername/BananaRepublicProfs/releases/latest)
2. Extract `BananaRepublicProfs.zip` to your `World of Warcraft/Interface/AddOns/` folder
3. Restart WoW
4. The minimap button will appear automatically!

### Manual
1. Clone this repository or download as ZIP
2. Copy the `BananaRepublicProfs` folder to `Interface/AddOns/`
3. Make sure all 5 files are present:
   - `BananaRepublicProfs.lua`
   - `BananaRepublicProfs.toc`
   - `BananaRepublicProfs.xml`
   - `BananaRepublicProfs_RecipeMaps.lua`
   - `BRP_MinimapIcon.tga`

## 🎮 Usage

### First Time Setup
1. Open any profession window (e.g., Alchemy)
2. The addon will automatically scan after 0.5 seconds
3. Click the minimap button or type `/brp show` to open the UI
4. Click "Datenbank mit der Gilde teilen" to share with your guild

### Commands

```
/brp show          — Open/close the UI
/brp scan          — Scan the currently open profession
/brp rescan        — Clear session cache (allow rescanning)
/brp send          — Send all professions to guild
/brp delete <prof> — Delete a specific profession (e.g., /brp delete Alchemy)
/brp delete all    — Delete ALL professions (careful!)
/brp scanbank      — Manually scan bank for materials
/brp export        — Export to CSV for Excel/Discord
/brp debug         — Toggle debug mode on/off
/brp help          — Show all commands
```

### Finding Crafters

1. Open the UI with `/brp show` or click the minimap button
2. Use the search field to find a recipe (e.g., "Flask")
3. Select a profession from the dropdown (e.g., "Alchemy")
4. Click on any recipe to see who can craft it
5. Click "Whisper" to message them directly!

### Sharing with Guild

- **Automatic:** Scans are automatically shared when you scan a profession
- **Manual:** Click "Datenbank mit der Gilde teilen" to send all at once
- **Status:** Watch the chat for "✅ Alle Berufe wurden gesendet!"

## 🔧 Advanced Features

### CSV Export
Export your entire guild's recipe database to Excel or Google Sheets:
```
/brp export
```
Then press `Ctrl+A` and `Ctrl+C` to copy, paste into a `.csv` file.

### Bank Integration
The addon automatically scans your bank when opened. You can also manually trigger:
```
/brp scanbank
```

### Debug Mode
See detailed information about scans and network traffic:
```
/brp debug
```

Clean output shows:
- "Scan geplant in 0.5 Sekunden..."
- "Scanne Beruf: Alchemy → Alchemy"
- "[SEND] Broadcasting to GUILD: YourName - Alchemy (12 chunks)"
- "✅ Alle Berufe wurden gesendet!"

## 📊 Technical Details

### Supported Professions
- Alchemy (245 recipes)
- Blacksmithing (200+ recipes)
- Enchanting (180+ recipes)
- Engineering (200+ recipes)
- Jewelcrafting (150+ recipes)
- Leatherworking (200+ recipes)
- Tailoring (180+ recipes)

**Total: 1,513 recipes**

### Network Protocol
- **Channel:** GUILD (addon messages)
- **Chunk Size:** Dynamically calculated (max 250 bytes)
- **Overhead:** Automatically computed based on player name length
- **Efficiency:** 50% fewer chunks than previous versions
- **Retry:** Automatic retry mechanism (up to 3 attempts)

### Data Storage
- **SavedVariables:** `BRPDB`
- **Per-Character:** Each character has separate profession data
- **Guild Database:** Shared database of all guild members
- **Bank Tracking:** Optional material tracking

### Compatibility
- **WoW Version:** 1.12 (Vanilla)
- **Tested On:** Turtle WoW (Tel'Abim server)
- **Dependencies:** None (standalone addon)

## 🖼️ Screenshots

### Main UI
![Main Interface](screenshots/main-ui.png)
*Search, filter, and find recipes instantly*

### Recipe Popup
![Recipe Details](screenshots/recipe-popup.png)
*Detailed recipe information with crafter list*

### Minimap Button
![Minimap Button](screenshots/minimap-button.png)
*Beautiful round button with Banana Republic logo*

## 🐛 Known Issues

None! The addon is production-ready and fully tested.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Coding Standards
- Use 2-space indentation
- Comment complex logic
- Follow existing code style
- Test on Turtle WoW before submitting

## 📝 Changelog

### Version 1.0.0 (2025-02-13)
- 🎉 **Initial Release**
- ✅ Full profession scanning (7 professions)
- ✅ Guild sharing with optimized network protocol
- ✅ Smart search with sub-category filters
- ✅ Minimap button with custom logo
- ✅ Automatic retry mechanism for reliable scans
- ✅ CSV export functionality
- ✅ Bank material tracking
- ✅ Clean, professional UI

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Luminarr** (Tel'Abim - Turtle WoW)

- In-game: Luminarr
- Server: Tel'Abim
- Guild: Banana Republic

## 🙏 Acknowledgments

- **Banana Republic Guild** on Tel'Abim for testing and feedback
- **Turtle WoW Team** for maintaining an amazing server
- **Vanilla WoW Community** for keeping the classic alive

## 💬 Support

### Need Help?
- **In-game:** Whisper Luminarr on Tel'Abim
- **Issues:** [GitHub Issues](https://github.com/yourusername/BananaRepublicProfs/issues)
- **Discord:** Join Turtle WoW Discord and find us in #tel-abim

### FAQ

**Q: Does this work on retail WoW?**  
A: No, this is designed for Vanilla 1.12 / Turtle WoW only.

**Q: Will it work on other Vanilla servers?**  
A: Yes! It should work on any 1.12 server with addon support.

**Q: Can I use it solo?**  
A: Yes, it works solo for tracking your own recipes. Guild features require guild membership.

**Q: How do I reset the database?**  
A: Use `/brp delete all` or delete the SavedVariables file.

**Q: The scan failed, what do I do?**  
A: The addon has automatic retry (3 attempts). If it still fails, use `/brp rescan` and try again.

**Q: Can I customize the minimap button position?**  
A: Yes! Right-click and drag it anywhere around the minimap.

---

**Made with ❤️ for the Banana Republic Guild** 🍌

*Happy Crafting!* 🎮
