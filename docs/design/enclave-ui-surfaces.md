# Enclave UI — Surfaces Tracker

Every surface of the Enclave experience to design and build, so none is missed.

Direction (reset 2026-11-17 — see
`../superpowers/specs/2026-11-17-enclave-os-v2-arch-windowslike-design.md`):
**Windows-*familiar*, cleaner and nicer.** Layout and navigation read like
Windows 11 so a Windows user instantly knows where everything is — but tidier,
calmer, lighter, with Enclave's own branding. Proposed visual language: calm and
flat-leaning, *restrained* translucency (not heavy glass), generous spacing, one
tasteful Enclave accent — not the retired orange→magenta "glass bloom". The
**floating control bubble** stays as the one signature non-Windows touch.
Built on **Arch + trimmed KDE Plasma 6 (Wayland/KWin)**.

> Superseded: the 2026-11-14 "warm vibrant glass" direction (orange bloom,
> frosted glass panels) is retired along with the NixOS base.

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
