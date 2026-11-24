# Enclave Shell — design and development sequence

Status: **approved direction**, 2026-11-24. Supersedes the "theme XFCE until it
looks right" approach of the v2 spec for everything above the window manager.

## 1. Decisions (locked)

| Area | Decision |
|---|---|
| Linux base | Arch Linux, built with archiso (unchanged) |
| Desktop | **Enclave Shell**, Enclave's own desktop shell |
| Display protocol | Wayland, XWayland for legacy X11 apps |
| Compositor / WM | labwc (wlroots) at first, behind an internal interface so it can be swapped |
| Shell UI | Qt 6 / QML for presentation, C++ for integration |
| Visual system | **Enclave Ember**: orange identity, adaptive light/dark |
| Assistant | Advisory-only (see `arch/assistant.md`) |
| Installer | Calamares (kept) |
| Login | SDDM (kept), with a Wayland session entry |

Principle: Enclave owns the experience, the shell and the integration, and
reuses proven infrastructure underneath. We do **not** write a display server or
compositor.

Two boundaries must hold:
- The shell never depends on labwc internals. It only uses standard Wayland
  protocols (layer-shell, foreign-toplevel) through its own `WindowManager`
  interface.
- Enclave Intelligence never depends on the shell.

## 2. Enclave Ember — colour system

Orange is Enclave's identity. It marks important interactions, active states
and branding. It is never the background of everything. Green, red and blue are
kept for status.

| Token | Value |
|---|---|
| `brand.ember` | `#FF7A1A` (primary accent) |
| `brand.solar` | `#FFAC55` (accent on dark, highlights) |
| `brand.burnt` | `#E95B16` (pressed / accent on light) |
| `brand.glow` | `#FFD0A6` (selection wash, focus glow) |

| Role | Ember Dark | Ember Light |
|---|---|---|
| background | Obsidian `#101114` | Porcelain `#F7F6F3` |
| surface | Graphite `#1A1C21` | Surface `#FFFFFF` |
| elevated | Elevated `#272A31` | Warm Grey `#EAE8E2` |
| text | `#F5F3EF` | `#202124` |

Status colours, secondary text and borders are derived in
`desktop/design-system/tokens/ember.json`, which is the single source of
truth. QML reads it through the `Ember` singleton, and the legacy GTK theme is
recoloured from it too. No surface hard-codes a colour.

Design rules: an 8 px spacing grid; 12 px radii on surfaces and 20–24 px on
floating panels; Inter for type; subtle blur rather than heavy transparency;
150–250 ms transitions; a reduced-motion setting; and light and dark that feel
like two expressions of one design. Appearance can be light, dark or follow the
system, and is switched from one shared setting.

## 3. Architecture

```
Enclave Shell (Qt 6 / QML, one process: enclave-shell)
  surfaces: Desktop/wallpaper · Taskbar · Start · Search · Control Center
            Notifications · Workspaces · Window bubble
  core:     WindowManager (iface) · AppRegistry (.desktop) · Settings · Theme
Enclave services (D-Bus): session · settings · notifications · power · audio
Compositor: labwc (wlroots) + XWayland    ← replaceable
Arch Linux: kernel · systemd · PipeWire · NetworkManager · UPower
```

- Panels, the desktop and the bubble are **layer-shell** surfaces
  (`layer-shell-qt`).
- Task list, minimise/maximise/close and the bubble's actions go through
  **wlr-foreign-toplevel-management**, which labwc implements. This lets the
  signature bubble survive the move to Wayland without breaking Wayland's
  security model.
- Applications come from standard XDG `.desktop` entries. There is no
  hard-coded catalogue. The existing `enclave-applications.menu` rules carry
  over.

## 4. Repository layout (new code only; `arch/` migrates later)

```
desktop/
  design-system/tokens/ember.json     colour, radius, spacing, motion tokens
  shell/                              CMake project → /usr/bin/enclave-shell
    src/        C++ (main, AppRegistry, Clock/System, WindowManager iface)
    qml/        Ember.qml singleton + one file per surface
  session/                            labwc config + session entry
tests/phase5-asserts.sh               static checks for the shell + session
```

`scripts/build-iso.sh` compiles `desktop/shell` in the build container, as it
already does for the panel plugins, and installs it into airootfs.

## 5. Migration

| Existing | Decision |
|---|---|
| Arch base, archiso, Calamares, SDDM, branding | keep |
| XFCE / xfwm4 / picom | **retired** (2026-11-24): Enclave Shell is the only session |
| GTK3 Start menu, X11 bubble | reference designs; reimplemented in QML |
| Audit reports | kept as history |

## 6. Development sequence

Each phase ends in something testable.

0. **Foundation** — clean ISO, boots to a desktop in a UEFI VM (VMware):
   **done** for the live session (2026-11-24). Still to do: an install to a
   blank disk, a reboot without the ISO, and checking that the created user
   survives cleanup.
1. **Wayland platform** — labwc, XWayland, portals (`xdg-desktop-portal-wlr`
   and `-gtk`), and the SDDM session "Enclave" that starts
   `enclave-session`. Keyboard, pointer and output configuration through labwc.
2. **Shell foundation** — the `enclave-shell` process and its lifecycle (it
   restarts on crash), layer-shell surfaces, the Ember theme engine, an
   AppRegistry, and the WindowManager interface plus its foreign-toplevel
   implementation.
3. **Ember design system** — tokens to QML components (Button, Card, Menu,
   SearchField, Toggle), with light/dark switching under 500 ms and reduced
   motion.
4. **Surfaces** — desktop and wallpaper, centred taskbar, Start (port of the
   GTK design), global search, Control Center, notifications, workspaces, and
   the bubble.
5. **System integration** — audio, network, Bluetooth, brightness, power,
   Files, settings, updates.
6. **Universal apps** — Flatpak/AUR, Wine/Proton, Waydroid.
7. **Enclave Intelligence** — advisory assistant (llama.cpp, OpenVox),
   isolated by process and permissions, not just a flag.

## 7. Release gates (before a release)

The shell starts in under 3 s, with no crashes in normal use. Both themes look
correct on every surface. Keyboard navigation works everywhere. XWayland apps
run. The bubble controls the active window. It works in a VM without 3D (the
software-rendering fallback). Install, reboot and login all pass in VMware.
