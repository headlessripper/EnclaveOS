# Enclave UI — Surfaces Tracker

Every surface of the Enclave experience to design and build, so none is missed.
Direction (locked 2026-11-14): **warm vibrant glass** — an orange→coral→magenta
bloom wallpaper, glossy frosted light-glass panels, a bold rounded orange taskbar,
the glossy launcher that fuses apps + widgets + recents + greeting. Windows-11/12
bones, unmistakably Enclave (orange `#FF7A3D` / coral `#F2506E`, logo, control
bubble). Widgets, popups, notifications, menus all share **one glass card system**.
Design system artifact: https://claude.ai/artifact/J6dtnG722icKTzUqFADo43

Status: ⬜ todo · 🟧 designing · ✅ design signed off · 🏗️ building · ✔️ shipped

## Foundations
- 🟧 Design language / tokens — color, type (Instrument Sans + mono), glass/Mica, radius, elevation, motion
- ⬜ Icon theme (app + system icons, Enclave logo set)
- ⬜ Wallpapers (default + light/Paper variants, the Enclave "bloom")
- ⬜ Sounds (startup, notification) — later

## Core surfaces
- 🟧 Desktop + launcher (bloom wallpaper, desktop icons, glossy launcher = apps+widgets+recents+greeting)
- 🟧 Lock screen (clock, date, assistant brief, media, unlock)
- 🟧 Login / greeter (avatar, name, password, power)
- 🟧 Settings app (frosted sidebar + panes, accent/glass/transparency controls)
- 🟧 Quick settings / Control center (toggles, sliders, AI pilot) — popup system
- 🟧 Notification center + toasts — popup system (same cards)
- 🟧 Window chrome + floating control bubble (frameless, drag, AI, split, min/max/close)
- 🟧 Global search / command palette (apps, files, actions, ask AI)
- 🟧 Context menus / popups (unified glass menu) — popup system
- 🟧 File manager (Files)
- 🟧 AI Assistant surface (window + voice HUD, OpenVox)
- 🟧 System dialogs (power, auth/password, confirm)

All core surfaces now designed in the Glass/Dark/Paper language (design-system v4).
Remaining design polish: icon theme redraw, finalized wallpapers. Then → build.

## Build (after design sign-off)
- ⬜ Compile the design into a system-wide Plasma theme (applies on first boot)
- ⬜ KWin decorations + rounded corners + blur
- ⬜ Rebuild graphical image, boot-verify

Reference mockups: Enclave Design System artifact (see chat).
Inspiration: Windows 11/12 (Mica, widgets board, floating taskbar), Alpha Code /
Aretlyx (dark glass, Instrument Sans, accent + glow, the bubble).
