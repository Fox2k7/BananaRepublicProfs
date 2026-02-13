# Contributing to BananaRepublicProfs 🍌

First off, thank you for considering contributing to BananaRepublicProfs! It's people like you that make this addon great for the entire Vanilla WoW community.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Pull Request Process](#pull-request-process)
- [Bug Reports](#bug-reports)
- [Feature Requests](#feature-requests)

## 📜 Code of Conduct

This project and everyone participating in it is governed by respect and collaboration. By participating, you are expected to uphold this code. Please be kind and constructive in all interactions.

## 🤝 How Can I Contribute?

### Reporting Bugs 🐛

Before creating bug reports, please check existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

**Required Information:**
- WoW version (should be 1.12)
- Server (e.g., Turtle WoW - Tel'Abim)
- Addon version
- Exact steps to reproduce
- Expected vs actual behavior
- Error messages (enable with `/console scriptErrors 1`)
- Screenshot if possible

**Example Bug Report:**
```
Title: "Scan fails for Enchanting with Lua error"

Environment:
- WoW 1.12.1
- Turtle WoW (Tel'Abim)
- BananaRepublicProfs v1.0.0

Steps to Reproduce:
1. Open Enchanting profession window
2. Wait for automatic scan
3. Error appears

Expected: Successful scan with recipe list
Actual: Lua error "attempt to index nil value"

Error Message:
[See attached screenshot]

Additional Context:
Alchemy and Blacksmithing scans work fine, only Enchanting fails.
```

### Suggesting Features 💡

Feature requests are welcome! Please provide:
- **Use case:** Why is this feature needed?
- **Proposed solution:** How would it work?
- **Alternatives:** What other solutions did you consider?
- **Mockups:** Visual examples if applicable

### Code Contributions 💻

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Make your changes
4. Test thoroughly on Turtle WoW
5. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
6. Push to the branch (`git push origin feature/AmazingFeature`)
7. Open a Pull Request

## 🛠️ Development Setup

### Prerequisites
- World of Warcraft 1.12.1 client
- Turtle WoW account (for testing)
- Text editor (VS Code, Sublime Text, Notepad++, etc.)
- Git

### Local Development

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/BananaRepublicProfs.git
   cd BananaRepublicProfs
   ```

2. **Symlink to WoW AddOns folder:**
   
   **Windows:**
   ```cmd
   mklink /D "C:\Program Files\World of Warcraft\Interface\AddOns\BananaRepublicProfs" "C:\path\to\your\clone"
   ```
   
   **Mac/Linux:**
   ```bash
   ln -s /path/to/your/clone /Applications/World\ of\ Warcraft/Interface/AddOns/BananaRepublicProfs
   ```

3. **Enable Lua errors in-game:**
   ```
   /console scriptErrors 1
   ```

4. **Test your changes:**
   - Make changes in your editor
   - Type `/reload` in-game
   - Test the functionality
   - Check for Lua errors

### Testing Checklist

Before submitting a PR, verify:
- [ ] No Lua errors in default gameplay
- [ ] Profession scanning works (all 7 professions)
- [ ] Guild sharing works
- [ ] Search and filters work
- [ ] Minimap button works
- [ ] All commands work (`/brp help`)
- [ ] UI doesn't break at different resolutions
- [ ] No memory leaks (test with `/dump collectgarbage("count")`)

## 🎨 Coding Standards

### Lua Style Guide

**Indentation:**
- Use 2 spaces (not tabs)
- Consistent indentation throughout

**Naming Conventions:**
- Global functions: `BRP_FunctionName`
- Local functions: `camelCase` or `snake_case`
- Constants: `UPPER_CASE`
- Frame names: `BRP_FrameName`

**Comments:**
```lua
-- Single-line comment

--[[
Multi-line comment
for complex logic
]]

-- Section headers
-- -------------------------
-- Section Name
-- -------------------------
```

**Example:**
```lua
-- -------------------------
-- Recipe Scanning
-- -------------------------
local function scanCurrentTradeSkill()
  local profName, rank, maxRank = GetTradeSkillLine()
  
  if not profName or profName == "" then
    debug("No profession window open")
    return false
  end
  
  -- Scan logic here...
  return true
end
```

### Code Organization

- **Keep functions short** (<50 lines if possible)
- **One function, one purpose** (Single Responsibility Principle)
- **Comment complex logic** but not obvious code
- **Use local variables** whenever possible (performance)
- **Avoid global pollution** (prefix globals with `BRP_`)

### Performance Best Practices

```lua
-- GOOD: Cache table.getn
local tlen = table.getn
local count = tlen(myTable)

-- BAD: Repeated function calls
for i = 1, table.getn(myTable) do
  -- table.getn is called every iteration!
end

-- GOOD: Cache globals
local _G = getfenv(0)
local pairs = pairs

-- GOOD: Local functions for hot paths
local function isOnline(playerName)
  -- Frequently called function
end
```

## 📝 Pull Request Process

### PR Checklist

- [ ] Branch is up-to-date with main
- [ ] Code follows style guidelines
- [ ] All tests pass
- [ ] No Lua errors
- [ ] Tested on Turtle WoW
- [ ] Updated CHANGELOG.md
- [ ] Updated README.md if needed
- [ ] Added comments for complex code

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
How was this tested?

## Screenshots (if applicable)
Add screenshots of UI changes

## Checklist
- [ ] No Lua errors
- [ ] Tested on Turtle WoW
- [ ] Updated CHANGELOG.md
```

### Review Process

1. Submit PR with complete description
2. Maintainer will review within 1-2 days
3. Address any requested changes
4. Once approved, PR will be merged
5. Your contribution will be in the next release! 🎉

## 🐞 Bug Reports

### Where to Report
- **GitHub Issues:** [Create an Issue](https://github.com/yourusername/BananaRepublicProfs/issues/new)
- **In-Game:** Whisper Luminarr on Tel'Abim
- **Discord:** Turtle WoW Discord - #tel-abim

### Bug Report Template

```markdown
**Describe the bug**
A clear description of what the bug is.

**To Reproduce**
1. Go to '...'
2. Click on '...'
3. See error

**Expected behavior**
What you expected to happen.

**Screenshots**
If applicable, add screenshots.

**Environment:**
- WoW Version: [e.g., 1.12.1]
- Server: [e.g., Turtle WoW - Tel'Abim]
- Addon Version: [e.g., 1.0.0]
- Other Addons: [list other addons if relevant]

**Additional context**
Any other information about the problem.
```

## 💡 Feature Requests

### Feature Request Template

```markdown
**Is your feature request related to a problem?**
A clear description of the problem.

**Describe the solution you'd like**
What you want to happen.

**Describe alternatives you've considered**
Any alternative solutions you thought of.

**Additional context**
Screenshots, mockups, or examples.
```

## 🔄 Development Workflow

### Git Workflow

1. **Create a branch** from `main`:
   ```bash
   git checkout -b feature/my-feature
   ```

2. **Make commits** with clear messages:
   ```bash
   git commit -m "Add feature: XYZ functionality"
   ```

3. **Push to your fork:**
   ```bash
   git push origin feature/my-feature
   ```

4. **Open a Pull Request** on GitHub

### Commit Message Format

```
<type>: <short description>

<optional longer description>

<optional footer>
```

**Types:**
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation only
- `style:` Code style (formatting, no logic change)
- `refactor:` Code refactoring
- `perf:` Performance improvement
- `test:` Adding tests
- `chore:` Maintenance tasks

**Examples:**
```
feat: Add CSV export functionality

Adds /brp export command to export recipes to CSV format
for use in Excel or Google Sheets.

Closes #42
```

```
fix: Scan retry mechanism not working

The retry counter was not resetting properly, causing
scans to fail after the first retry attempt.

Fixes #56
```

## 📚 Resources

### Vanilla WoW API Reference
- [WoWWiki (Vanilla)](https://wowwiki-archive.fandom.com/wiki/World_of_Warcraft_API)
- [Turtle WoW Wiki](https://turtle-wow.fandom.com/)

### Lua Documentation
- [Lua 5.0 Reference Manual](https://www.lua.org/manual/5.0/)
- [Programming in Lua (1st edition)](https://www.lua.org/pil/contents.html)

### Testing Server
- [Turtle WoW](https://www.turtle-wow.org/)
- Discord: Join for #tel-abim channel

## 🙏 Recognition

Contributors will be:
- Listed in CHANGELOG.md
- Mentioned in release notes
- Added to the README credits section
- Eternally grateful from the Banana Republic guild! 🍌

## ❓ Questions?

Have questions about contributing? 

- **In-game:** Whisper Luminarr on Tel'Abim
- **GitHub:** Comment on an issue
- **Discord:** Turtle WoW - #tel-abim channel

---

**Thank you for contributing to BananaRepublicProfs!** 🎮🍌
