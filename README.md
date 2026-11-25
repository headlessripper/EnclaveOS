# Enclave OS

A polished, lightweight Linux distribution that **feels like a cleaner, calmer
Windows** — familiar layout and navigation, Enclave's own identity, and the apps
you already rely on (Windows, Android, Linux) running side by side.

- **Base:** Arch Linux, shipped as a branded `archiso` ISO.
- **Desktop: Enclave Shell** — Enclave's own desktop, Qt 6 / QML on Wayland
  (Hyprland when the machine has a GPU, labwc otherwise), in the **Enclave
  Ember** design system (orange identity, adaptive light/dark). No top bar:
  a floating "Now" widget (time, network, battery) and a floating search
  widget (apps, settings, files, sums, the web), a floating centred dock
  (windows gather under their pinned icon, a window list on hover, drag to
  reorder, Trash, auto-hide), Start with a category rail, Control Center,
  calendar, live desktop widgets, the "Ember Horizon" wallpapers, and a clean
  desktop (icons only where you add them). **Enclave Settings** holds every
  system page (network, sound, displays, appearance, dock, power, Activity —
  the task manager — storage, date & time, keyboard, about), and **Enclave
  Terminal** is the terminal.
  Windows have no title bar: each gets the slim Enclave frame and is
  controlled from Enclave's signature floating **bubble**. Enclave Icons
  (Enclave's own squircle app, folder and device icons on a Papirus base),
  Inter font, an Ember boot splash. See `desktop/` and
  `docs/superpowers/specs/2026-11-24-enclave-shell-design.md`.
- **Default apps:** Zen Browser, Thunderbird, Files, Text Editor, Photos
  (Ristretto), Media Player (Celluloid), Terminal, Settings (with Activity,
  the task manager).
- **Apps:** Linux (Flatpak/AUR), Windows (Wine/Proton), Android (Waydroid).
- **Assistant:** a helpful, **advisory** assistant + OpenVox voice — answers and
  helps, never operates the machine.

## Layout

| Path | What |
|---|---|
| `arch/` | The Arch `archiso` profile (overlay + build inputs) — see `arch/README.md` |
| `scripts/build-iso.sh` | Builds the branded ISO (run on Arch, as root) |
| `assets/branding/` | Enclave logo / icon pack |
| `docs/superpowers/specs/` | Design docs — current: `2026-11-17-…-arch-windowslike-design.md` |
| `tests/` | Phase assertion scripts |
| `legacy/` | Retired v1 NixOS base (reference only) |

## Build

```bash
# On Arch (WSL-Arch or a VM):
sudo pacman -S --needed archiso git base-devel sudo sassc librsvg plymouth gtk-update-icon-cache \
  cmake wlr-protocols wayland-protocols qt6-base qt6-declarative qt6-wayland qt6-svg layer-shell-qt
sudo scripts/build-iso.sh

# On WSL Ubuntu / any host with Docker:
scripts/build-iso-docker.sh
```

The build needs `mkarchiso` (Arch-only); the Docker path runs it in an
`archlinux` container so it works from Ubuntu. Output ISO lands in `dist/`.

## Status

Phase 0 (Arch foundation + branding) scaffolded. See the design doc for the full
phase plan: Foundation → Desktop (priority) → Universal apps → Assistant + voice.
