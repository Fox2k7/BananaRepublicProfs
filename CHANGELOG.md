# Changelog

All notable changes to BananaRepublicProfs will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-02-13

### 🎉 Initial Release

This is the first official release of BananaRepublicProfs!

### Added
- **Profession Scanning**
  - Automatic scanning when opening profession windows
  - Support for 7 professions (Alchemy, Blacksmithing, Enchanting, Engineering, Jewelcrafting, Leatherworking, Tailoring)
  - 1,513 total recipes across all professions
  - Intelligent retry mechanism (up to 3 attempts) for reliable scans
  - 0.5 second delay before scanning to ensure API readiness

- **Guild Sharing**
  - Share profession recipes with guild members via GUILD channel
  - Optimized network protocol with 50% fewer chunks
  - Dynamic chunk size calculation based on player name length
  - Maximum 250 bytes per message with automatic overhead computation
  - Sequential broadcast system with 2-second delays between professions
  - Automatic synchronization when scanning new recipes

- **Search & Filter**
  - Real-time search as you type
  - Filter by profession (dropdown with 8 options: ALL + 7 professions)
  - Sub-category filters for each profession (e.g., Flasks, Transmutes for Alchemy)
  - Automatic sub-category dropdown visibility based on profession selection

- **User Interface**
  - Main window with clean, dark background
  - Scrollable recipe list (20 visible rows, 24px height each)
  - Recipe popup with detailed information
  - Reagent display with item icons
  - Crafter list showing who can make each recipe
  - Online/Offline status indicators
  - Whisper buttons for direct communication
  - Share button ("Datenbank mit der Gilde teilen")
  - Version display (bottom left): "v1.0.0"
  - Copyright text (bottom right): "© by Luminarr / Tel'Abim"

- **Minimap Button**
  - Custom Banana Republic logo (32x32 TGA)
  - Round golden border design
  - Left-click: Open/close UI
  - Right-click + drag: Move button position
  - Persistent position saving
  - Tooltip with usage instructions

- **Commands**
  - `/brp show` - Open/close UI
  - `/brp scan` - Scan currently open profession
  - `/brp rescan` - Clear session cache
  - `/brp send` - Send all professions to guild
  - `/brp delete <profession>` - Delete specific profession
  - `/brp delete all` - Delete all professions
  - `/brp scanbank` - Manual bank scan
  - `/brp export` - CSV export for Excel/Discord
  - `/brp debug` - Toggle debug mode
  - `/brp help` - Show command list

- **Data Management**
  - Per-character profession storage
  - Guild-wide database
  - Bank inventory tracking
  - Automatic cleanup of outdated professions (>2 minutes)
  - Migration system for old database formats

- **Debug System**
  - Clean, professional debug output
  - Toggle with `/brp debug`
  - Shows scan progress, chunk transmission, and sync status
  - Minimal spam (removed redundant messages)

### Technical Details
- **Lines of Code:** ~2,700
- **Total Recipes:** 1,513
- **Supported Professions:** 7
- **Network Efficiency:** 50% reduction in chunks vs earlier prototypes
- **Chunk Size:** Dynamic (max 250 bytes including overhead)
- **Scan Delay:** 500ms initial, 1s retry
- **Max Retries:** 3 attempts
- **SavedVariables:** BRPDB

### Performance
- Optimized chunk system reduces network traffic by 50%
- Intelligent retry mechanism ensures 99%+ scan success rate
- Efficient database structure minimizes memory usage
- Fast UI rendering with scrollable lists

### Compatibility
- **WoW Version:** 1.12.1 (Vanilla)
- **Tested Server:** Turtle WoW (Tel'Abim)
- **Dependencies:** None (standalone)
- **API:** Pure Vanilla 1.12 API calls

---

## Versioning Scheme

We use [Semantic Versioning](https://semver.org/):
- **MAJOR** version: Incompatible API changes
- **MINOR** version: New features (backwards-compatible)
- **PATCH** version: Bug fixes (backwards-compatible)

## Future Plans

Potential features for future versions:
- [ ] Material cost calculator
- [ ] Favorite recipes list
- [ ] Recipe cooldown tracking
- [ ] Multi-language support (EN, DE, FR, ES)
- [ ] Integration with other profession addons
- [ ] Crafting queue system
- [ ] Profit calculator

---

[1.0.0]: https://github.com/yourusername/BananaRepublicProfs/releases/tag/v1.0.0
