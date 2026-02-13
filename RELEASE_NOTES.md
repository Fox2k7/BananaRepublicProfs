# BananaRepublicProfs v1.0.0 🎉🍌

## First Official Release!

**BananaRepublicProfs** is now production-ready for Vanilla WoW / Turtle WoW!

A comprehensive guild profession database addon with smart search, sharing, and a beautiful UI.

---

## 🚀 What's New

### ✨ Core Features

- **📚 Complete Recipe Database**
  - 1,513 recipes across 7 professions
  - Automatic scanning when opening profession windows
  - Intelligent retry system (never fails to scan!)
  - Support for: Alchemy, Blacksmithing, Enchanting, Engineering, Jewelcrafting, Leatherworking, Tailoring

- **🔍 Powerful Search System**
  - Real-time search as you type
  - Filter by profession (ALL + 7 professions)
  - Sub-category filters (Flasks, Transmutes, Weapon enchants, etc.)
  - Instant results

- **👥 Guild Sharing**
  - Share your recipes with the entire guild
  - See who can craft what you need
  - Online/Offline status indicators
  - Optimized network traffic (50% fewer chunks!)
  - Automatic synchronization

- **💬 Direct Communication**
  - Whisper crafters directly from the UI
  - Copy recipe links to chat
  - Multi-crafter support

- **🗺️ Minimap Button**
  - Beautiful round design with Banana Republic logo
  - Left-click: Open/close UI
  - Right-click + drag: Move position
  - Persistent settings

### 🎨 User Interface

- Modern, clean design with dark theme
- Scrollable recipe lists (20+ per page)
- Detailed recipe popups with reagent information
- Version info (v1.0.0) and copyright display
- Responsive and fast

### ⚡ Performance

- **50% network efficiency improvement** over prototypes
- Dynamic chunk size calculation
- Intelligent overhead management
- Fast UI rendering
- Minimal memory footprint

---

## 📦 Installation

### Quick Install

1. **Download** `BananaRepublicProfs-v1.0.0.zip`
2. **Extract** to `World of Warcraft/Interface/AddOns/`
3. **Restart** WoW
4. **Done!** The minimap button will appear automatically

### Detailed Instructions

See [INSTALLATION.md](INSTALLATION.md) for step-by-step guide with troubleshooting.

---

## 🎮 Quick Start

### First Use

1. Open any profession window (e.g., Alchemy)
2. Wait 0.5 seconds - automatic scan!
3. Click the minimap button (Banana logo 🍌)
4. Search for recipes and see who can craft them
5. Click "Datenbank mit der Gilde teilen" to share

### Essential Commands

```
/brp show    — Open/close UI
/brp scan    — Scan current profession
/brp send    — Share all professions with guild
/brp help    — Show all commands
```

### Finding Crafters

1. Open UI (`/brp show` or click minimap)
2. Search for a recipe (e.g., "Flask")
3. Select profession from dropdown
4. Click recipe → see all crafters
5. Click "Whisper" to message them!

---

## 📋 Complete Command List

| Command | Description |
|---------|-------------|
| `/brp show` | Open/close the UI |
| `/brp scan` | Scan currently open profession |
| `/brp rescan` | Clear cache, allow rescanning |
| `/brp send` | Send all professions to guild |
| `/brp delete <prof>` | Delete specific profession |
| `/brp delete all` | Delete ALL professions |
| `/brp scanbank` | Manually scan bank |
| `/brp export` | Export to CSV for Excel |
| `/brp debug` | Toggle debug mode |
| `/brp help` | Show command list |

---

## 🔧 Technical Details

### Supported Professions

| Profession | Recipes | Sub-Categories |
|------------|---------|----------------|
| Alchemy | 245 | Flasks, Potions, Transmutes, etc. |
| Blacksmithing | 200+ | Armor, Weapons, etc. |
| Enchanting | 180+ | Weapon, Armor, Shield, etc. |
| Engineering | 200+ | Explosives, Gadgets, etc. |
| Jewelcrafting | 150+ | Rings, Necklaces, etc. |
| Leatherworking | 200+ | Armor, Kits, etc. |
| Tailoring | 180+ | Cloth Armor, Bags, etc. |

**Total:** 1,513 recipes

### Network Protocol

- **Channel:** GUILD (addon messages)
- **Chunk Size:** Dynamic (max 250 bytes)
- **Efficiency:** 50% fewer chunks than v0.x
- **Reliability:** Automatic retry (up to 3 attempts)

### Compatibility

- **WoW Version:** 1.12.1 (Vanilla)
- **Tested On:** Turtle WoW (Tel'Abim server)
- **Dependencies:** None
- **File Size:** ~150 KB total

---

## 📸 Screenshots

### Main UI
![Main Interface](https://via.placeholder.com/800x600?text=Main+UI+Screenshot)
*Search, filter, and browse 1,513 recipes*

### Recipe Details
![Recipe Popup](https://via.placeholder.com/600x400?text=Recipe+Popup)
*See reagents and all crafters*

### Minimap Button
![Minimap Button](https://via.placeholder.com/200x200?text=Minimap+Button)
*Banana Republic logo with round border*

---

## 🐛 Known Issues

**None!** This is a stable v1.0.0 release.

If you find any issues, please [report them](https://github.com/yourusername/BananaRepublicProfs/issues).

---

## 🆙 Upgrading from Beta

If you used a pre-release version:

1. **Backup** your SavedVariables (optional)
2. **Delete** the old addon folder
3. **Install** v1.0.0 as normal
4. **Type** `/reload` in-game
5. Your data should migrate automatically!

---

## 📚 Documentation

- **README.md** - Full feature overview
- **INSTALLATION.md** - Detailed installation guide
- **CHANGELOG.md** - Complete version history
- **CONTRIBUTING.md** - How to contribute
- **LICENSE** - MIT License

---

## 🙏 Credits

**Developed by:** Luminarr (Tel'Abim - Turtle WoW)

**Special Thanks:**
- Banana Republic Guild for testing and feedback
- Turtle WoW Team for an amazing server
- Vanilla WoW community for keeping the classic alive

---

## 💬 Support

### Get Help

- **In-Game:** Whisper **Luminarr** on Tel'Abim
- **GitHub:** [Open an Issue](https://github.com/yourusername/BananaRepublicProfs/issues)
- **Discord:** Turtle WoW Discord - #tel-abim

### Report Bugs

Found a bug? Please include:
- WoW version (1.12.1)
- Server (Turtle WoW)
- Exact steps to reproduce
- Error message (enable with `/console scriptErrors 1`)
- Screenshot if possible

---

## 🎯 What's Next?

### Planned Features (v1.1.0+)

- Material cost calculator
- Favorite recipes list
- Recipe cooldown tracking
- Multi-language support
- Crafting queue system
- Profit calculator

**Want to contribute?** See [CONTRIBUTING.md](CONTRIBUTING.md)!

---

## 📄 Files Included

```
BananaRepublicProfs/
├── BananaRepublicProfs.lua           (81 KB) - Main code
├── BananaRepublicProfs.toc           (285 B) - Addon metadata
├── BananaRepublicProfs.xml           (2.3 KB) - Minimap UI
├── BananaRepublicProfs_RecipeMaps.lua (60 KB) - Recipe categories
└── BRP_MinimapIcon.tga               (3.1 KB) - Banana logo
```

**Total:** ~150 KB
**Lines of Code:** ~2,700

---

## 📜 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

---

## 🍌 Final Words

Thank you for using **BananaRepublicProfs**!

This addon was built with ❤️ for the Banana Republic guild and the entire Vanilla WoW community.

**Happy Crafting!** 🎮

---

Made with 🍌 by Luminarr / Tel'Abim

*For the Banana Republic!*
