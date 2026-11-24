# Enclave OS

A polished, lightweight Linux distribution that **feels like a cleaner, calmer
Windows** — familiar layout and navigation, Enclave's own identity, and the apps
you already rely on (Windows, Android, Linux) running side by side.

- **Base:** Arch Linux, shipped as a branded `archiso` ISO.
- **Desktop:** trimmed KDE Plasma 6 (Wayland/KWin), themed Windows-familiar but
  cleaner, with Enclave's signature floating **control bubble** on every window.
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
sudo pacman -S --needed archiso && sudo scripts/build-iso.sh

# On WSL Ubuntu / any host with Docker:
scripts/build-iso-docker.sh
```

The build needs `mkarchiso` (Arch-only); the Docker path runs it in an
`archlinux` container so it works from Ubuntu. Output ISO lands in `dist/`.

## Status

Phase 0 (Arch foundation + branding) scaffolded. See the design doc for the full
phase plan: Foundation → Desktop (priority) → Universal apps → Assistant + voice.
