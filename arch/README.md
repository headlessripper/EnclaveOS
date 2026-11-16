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
    packages.x86_64.extra  # appended to releng's package list (Plasma, SDDM, NM…)
    airootfs/              # identity, branding, services, live user, autologin
  profiledef.overrides     # key=value identity lines sed'd into releng/profiledef.sh
  branding/                # logo/wallpaper assets copied into the image
```

## Build

Output ISO lands in `../dist/`. The build needs `mkarchiso` (Arch-only), root,
and loop devices — so pick the path that matches your machine:

**On Arch (WSL-Arch or an Arch VM):**
```bash
sudo pacman -S --needed archiso
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
