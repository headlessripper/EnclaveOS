# Enclave OS

A polished, lightweight Linux distribution that **feels like a cleaner, calmer
Windows** — familiar layout and navigation, Enclave's own identity, and the apps
you already rely on (Windows, Android, Linux) running side by side.

- **Base:** Arch Linux, shipped as a branded `archiso` ISO.
- **Desktop:** XFCE on X11, shaped into a Windows 11 layout with macOS polish:
  centred taskbar with pinned apps, Enclave's own Windows-11-style Start menu
  (pinned apps, Recommended, All apps, instant search), Fluent-based Enclave
  theme / icons / cursor, Inter font, picom shadows + blur, and Enclave's
  signature floating **control bubble**.
- **Enclave Shell (in progress):** Enclave's own desktop — Qt 6 / QML on
  Wayland (labwc underneath), in the **Enclave Ember** design system (orange
  identity, adaptive light/dark). Pick **Enclave (Wayland preview)** on the
  login screen; XFCE stays the default until the shell passes its release
  gates. See `desktop/` and `docs/superpowers/specs/2026-11-24-enclave-shell-design.md`.
- **Default apps:** Zen Browser, Thunderbird, Files, Text Editor, Photos
  (Ristretto), Media Player (Celluloid), Task Manager.
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
sudo pacman -S --needed archiso git base-devel sudo sassc librsvg plymouth gtk-update-icon-cache xfce4-panel \
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
