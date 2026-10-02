# kNotes

A high-fidelity native macOS notes app powered by a Google Keep backend. Built in native Swift 6 / SwiftUI with a local offline-first Python `gkeepapi` daemon.

<p align="center">
  <img src="Resources/AppIcon.svg" width="128" height="128" alt="kNotes Icon" />
</p>

---

## Features

- **Native macOS Experience**: 3-column NavigationSplitView, liquid glass vibrancy, unified search, tags, and curated pastel color palettes.
- **Offline-First & Fast**: Zero-delay local caching (`~/.knotes`) with background bidirectional synchronization to Google Keep.
- **Interactive Checklists**: Drag-and-drop reordering, keyboard navigation, and completion state.
- **Rich Markdown Preview**: Live markdown rendering toggle via the topbar with zero editing clutter.
- **macOS System Integration**:
  - **CoreSpotlight & Siri**: Search and open notes directly from Spotlight without shortcut errors.
  - **Menu Bar Quick Capture**: Capture thoughts instantly from the menu bar (`kNotes` popover).
  - **Raycast & CLI**: Terminal command `knotes` and native Raycast script commands.
  - **Native Share Sheet**: Share notes seamlessly using macOS standard share targets.
- **Light & Dark Mode**: Full adaptive interface with balanced contrast and custom liquid glass icons for light and dark themes.

---

## Installation

### Prerequisites
- macOS 14.0+ (Sonoma or Sequoia)
- Swift 6.0+ toolchain
- Python 3.10+

### Option 1: Download Pre-built DMG
Download the latest `kNotes-v0.1-macOS.dmg` from the [Releases](https://github.com/madhuraj0/KNotes/releases) page, open it, and drag `kNotes` to your Applications folder.

### Option 2: Build & Install from Source
Clone the repository and run the automated installer:
```bash
git clone https://github.com/madhuraj0/KNotes.git
cd KNotes
./scripts/build_and_install.sh
```
This compiles the release binary, sets up the local runtime, and installs the signed app to `/Applications/kNotes.app`.

Launch via Spotlight (`⌘Space` -> `kNotes`) or Terminal:
```bash
open /Applications/kNotes.app
```

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `⌘N` | New Note |
| `⇧⌘N` | New Checklist |
| `⌘F` | Search All Notes |
| `⌘S` | Sync with Google Keep |
| `⌘T` | New Tag / Label |
| `⌘,` | Google Keep Account Settings |
| `⌘⌫` | Delete Note |

---

## Attributions

- **[gkeepapi](https://github.com/kiwiz/gkeepapi)**: The open-source Google Keep API client created by **Kai (kiwiz)**.
- **[FastAPI](https://fastapi.tiangolo.com)**: Local asynchronous API framework.

---

## License

MIT License © 2026 Madhuraj
