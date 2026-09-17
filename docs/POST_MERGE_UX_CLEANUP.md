# Post-Merge UX Consistency & Legacy Cleanup

## 1. Executive Summary & Principles

Following the integration of Quickshell as the canonical desktop shell for `fedora-sway-setup`, this cleanup aligns the desktop around a coherent, minimal, Quickshell-first architecture:

- **Quickshell**: State observation, quick actions, popups, and daily overlay UI (bar, launcher, clipboard, native shortcuts, notifications).
- **Kitty Floating + Dedicated TUI**: Advanced system configuration (`bluetui` for Bluetooth management, `nmtui` for NetworkManager).
- **Invisible Helpers**: Lightweight execution backends (`workstation-shell`, `workstation-screenshot`, `workstation-system-tool`, `workstation-network`) without redundant standalone graphical layers.

All obsolete scaffolding from previous iterations (Waybar, Fuzzel, Mako, and manual light theme switchers) has been removed completely.

---

## 2. Key Architecture Adjustments

### NetworkManager (`nmtui` in Floating Kitty)
- Preserved the fast, event-driven `libnm` Python integration inside Quickshell for Wi-Fi scanning, connection toggles, and IP status observation.
- Deprecated and removed `nm-connection-editor` and `workstation-network-editor`.
- Added `NetworkManager-tui` to the official Fedora desktop package list (`modules/75-sway-desktop.sh`).
- Created `workstation-network` (symlinked from `dotfiles/scripts/.local/bin/workstation-network` to `bin/workstation-network`), invoking `workstation-system-tool network` to launch `nmtui` in a centered, floating Kitty terminal matching the `bluetui` window rule.
- Wired the "Configurazione avanzata · nmtui" button in `NetworkPopup.qml` and `network.py` directly to `workstation-network`.

### Native Quickshell Shortcuts Help Panel
- Deprecated and deleted `sway-shortcuts`, `sway-help`, `workstation-app-menu`, and legacy desktop files (`sway-shortcuts.desktop`, `workstation-sway-help.desktop`).
- Implemented `ShortcutsData.js` and `ShortcutsPopup.qml` in `dotfiles/quickshell/.config/quickshell/workstation/shortcuts/`.
- Bound `Super+G` in Sway configuration to `workstation-shell shortcuts`, rendering an interactive, searchable overlay adhering to the canonical theme.

### Theme & Palette Single Source of Truth
- Unified color definitions in `config/palette.env` (`ACCENT_COLOR="#e88923"`, `BACKGROUND_COLOR="#111111"`, `BORDER_FOCUSED="#e88923"`, `BORDER_UNFOCUSED="#242424"`).
- Removed unfinished and fake light theme templates (`templates/themes/light/`).
- Streamlined `workstation-theme` to enforce Adwaita Dark and orange accent `#e88923` across GTK (`prefer-dark`), Qt portal, Sway, and Kitty.
- Deleted obsolete `workstation-theme.desktop`.

### Complete Legacy Scaffolding & Fallback Removal
- Removed `dotfiles/waybar/` and `waybar` from Stow packages.
- Removed `fuzzel.ini`, `mako.conf`, and `waybar.css` templates.
- Removed `waybar-cpu-temperature` and `workstation-notifications.py`.
- Simplified `workstation-bar.sh` to directly execute `quickshell --no-duplicate` (with `restart` and `run` actions).
- Removed the `--no-quickshell` flag from `install.sh` and made module `76-quickshell.sh` unconditional.
- Removed all legacy checks from `bin/doctor.sh`, `bin/doctor-quickshell.sh`, `bin/provenance-audit.sh`, and the test suite.

---

## 3. Verification & Compliance

- **Sway Compositor**: Borders `#e88923` focused, `#242424` unfocused, inner gaps 8px, outer gaps 0px.
- **GNU Stow**: Dotfiles packages tracked cleanly without unversioned runtime drift.
- **Audits & Doctor**:
  - `./bin/doctor.sh`: PASS (< 1.5s, all components OK).
  - `./bin/provenance-audit.sh`: PASS (100% official Fedora RPMs and verified SHA-256 release digests).
  - `./bin/test.sh`: PASS (full suite: shell syntax, shellcheck, QML mock tests, runtime headless sway tests).
