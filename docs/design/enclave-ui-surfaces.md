# Enclave UI — Surfaces Tracker

Every surface of the Enclave experience to design and build, so none is missed.
Mature, Windows-11/12-familiar, unmistakably Enclave (dark glass + orange `#FF6A13`,
logo, control bubble). Widgets, popups, notifications, menus all share **one glass
card system**.

Status: ⬜ todo · 🟧 designing · ✅ design signed off · 🏗️ building · ✔️ shipped

## Foundations
- 🟧 Design language / tokens — color, type (Instrument Sans + mono), glass/Mica, radius, elevation, motion
- ⬜ Icon theme (app + system icons, Enclave logo set)
- ⬜ Wallpapers (default + light/Paper variants, the Enclave "bloom")
- ⬜ Sounds (startup, notification) — later

## Core surfaces
- 🟧 Lock screen (clock, date, notifications, media, unlock)
- ⬜ Login / greeter (SDDM, user, avatar, power)
- 🟧 Desktop (wallpaper, desktop icons, right-click menu)
- 🟧 Widgets board (Win11-style glass board: clock, calendar, weather, photos, to-do, system, AI)
- 🟧 Start / launcher (search + AI, pinned, recommended, user, power)
- ⬜ Global search / command palette (apps, files, actions, ask AI)
- 🟧 Taskbar (floating island, pinned, running indicators, system tray)
- 🟧 Quick settings / Control center (toggles, sliders, AI pilot) — popup system
- ⬜ Notification center + toasts — popup system (same cards)
- ⬜ Context menus / popups (unified glass menu) — popup system
- 🟧 Window chrome + floating control bubble (frameless, drag, min/max/close, AI, pin, split)
- ⬜ Settings app (sidebar + panes, Enclave-styled)
- ⬜ File manager (Files)
- ⬜ AI Assistant surface (window + voice HUD, OpenVox)
- ⬜ System dialogs (power, auth/password, confirm)

## Build (after design sign-off)
- ⬜ Compile the design into a system-wide Plasma theme (applies on first boot)
- ⬜ KWin decorations + rounded corners + blur
- ⬜ Rebuild graphical image, boot-verify

Reference mockups: Enclave Design System artifact (see chat).
Inspiration: Windows 11/12 (Mica, widgets board, floating taskbar), Alpha Code /
Aretlyx (dark glass, Instrument Sans, accent + glow, the bubble).
