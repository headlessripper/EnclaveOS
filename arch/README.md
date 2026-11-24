# Enclave OS — Arch base (`archiso` profile)

Phase 0 of the [v2 design](../docs/superpowers/specs/2026-11-17-enclave-os-v2-arch-windowslike-design.md):
a branded, lightweight **Arch Linux** live/install ISO that boots to a basic
graphical session, replacing the retired NixOS base (now under `../legacy/nixos/`).

## How it's structured

Rather than hand-copy archiso's whole boot config (which drifts between releng
versions), Enclave ships only its **changes** as an overlay and assembles the
final profile from the system `releng` profile at build time. This keeps the
boot plumbing correct and the repo small.

```
arch/
  overlay/                 # Enclave's changes, layered on top of `releng`
    pacman.conf            # + [multilib] (needed for Wine/Proton later)
    packages.x86_64.extra  # appended to releng's package list (XFCE, SDDM, apps…)
    airootfs/              # identity, branding, services, live user, autologin
  profiledef.overrides     # key=value identity lines sed'd into releng/profiledef.sh
  branding/                # logo/wallpaper assets copied into the image
```

## Build

Output ISO lands in `../dist/`. The build needs `mkarchiso` (Arch-only), root,
and loop devices — so pick the path that matches your machine:

**On Arch (WSL-Arch or an Arch VM):**
```bash
sudo pacman -S --needed archiso git base-devel sudo sassc librsvg plymouth gtk-update-icon-cache xfce4-panel \
  cmake wlr-protocols wayland-protocols qt6-base qt6-declarative qt6-wayland qt6-svg layer-shell-qt
sudo ../scripts/build-iso.sh
```

**On WSL Ubuntu (or any non-Arch host with Docker/Podman):**
```bash
../scripts/build-iso-docker.sh
```
This runs the whole build inside the official `archlinux` container
(`--privileged`), so it works from Ubuntu without installing Arch. Requires
Docker (Docker Desktop with WSL integration, or `sudo apt install docker.io`).

> It will not run on the Windows host directly — use WSL or a VM.

## Keeping it lean

The build strips Arch's live-ISO bloat so the image stays light:
- `overlay/packages.remove` — niche releng packages removed from the final
  package set (IRC/web clients, legacy dial-up stacks, obscure wifi firmware,
  disk-imaging tools). Non-present entries are harmless no-ops.
- `overlay/pacman.conf` `NoExtract` — drops man pages, docs, and non-English
  locales at install time (licenses and English help are kept).

The build log prints the before/after package count.

**No bloat apps.** The desktop is a curated XFCE set (not the `xfce4` group).
The Start menu shows one flat, de-cluttered app list
(`airootfs/usr/share/enclave/menus/enclave-applications.menu`): individual
settings panels live inside the single **Settings** app, and technician tools
pulled in by the base system are hidden.

## Enclave Shell (Wayland preview session)

Enclave's own desktop lives in `../desktop/` and is compiled by
`build-iso.sh` (step 6b3) into the image:

| Piece | File |
|---|---|
| Colours, radii, motion (Enclave Ember) | `desktop/design-system/tokens/ember.json` |
| Shell (taskbar, Start, bubble, wallpaper) | `desktop/shell/` → `/usr/bin/enclave-shell` |
| Session launcher | `desktop/session/rootfs/usr/bin/enclave-session` |
| Window manager config (labwc) | `desktop/session/rootfs/usr/share/enclave/labwc/` |
| Window frames | `desktop/session/rootfs/usr/share/themes/Enclave-Ember/labwc/themerc` |

The XFCE session below remains the default (and the live session) until the
shell is validated.

## Where the desktop look comes from

| Piece | File |
|---|---|
| Taskbar layout | `airootfs/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml` |
| Taskbar true centring | `arch/plugins/enclave-balancer/` (C panel plugin, compiled by `build-iso.sh`) |
| Taskbar pinned apps | `airootfs/etc/xdg/xfce4/panel/docklike.rc` |
| Start menu | `airootfs/usr/local/bin/enclave-start` (+ `enclave-start-toggle`, default pins in `usr/share/enclave/start-defaults.json`) |
| Taskbar styling | `airootfs/etc/skel/.config/gtk-3.0/gtk.css` |
| Theme / icons / cursor | built from pinned Fluent sources in `scripts/build-iso.sh` (step 6b) |
| Window manager | `…/xfce-perchannel-xml/xfwm4.xml` |
| Compositor | `airootfs/etc/skel/.config/picom.conf` + `usr/local/bin/enclave-compositor` |
| Floating bubble | `airootfs/usr/local/bin/enclave-bubble` (see `bubble.md`) |
| Default apps | `airootfs/etc/xdg/mimeapps.list` |

**File modes:** mkarchiso discards file modes from `airootfs/` and applies only
`file_permissions` from `profiledef.sh`. `build-iso.sh` registers everything in
`usr/local/bin` there — a plain `chmod` would be silently lost.
