# Enclave — universal app compatibility (Phase 2)

Goal: run Linux, Windows, and Android apps from one desktop. How each is wired,
and the honest caveats.

## Linux apps — Flatpak + AUR (baked in)
- `flatpak` ships in the image; `enclave-flathub.service` registers the Flathub
  remote on first network connection.
- Native Arch packages come from `[core]`/`[extra]`/`[multilib]` (and later a
  signed `[enclave]` repo for `.enc` apps).

## Windows apps — Wine (baked in), Proton (opt-in)
- `wine` + `winetricks` ship in the image. Double-clicking a `.exe`/`.msi` runs
  it via `enclave-run-windows` (MIME handlers in `mimeapps.list`), using a tidy
  Enclave Wine prefix at `~/.local/share/enclave/wine`.
- **Proton / Steam** are large and better installed post-install:
  `enclave-appsetup gaming` installs Steam (Proton is enabled per-title in
  Steam's compatibility settings).

## Android apps — Waydroid (opt-in)
- Waydroid is **AUR-only** and needs the kernel's **binder** modules, so it is
  not baked into the ISO. `enclave-appsetup android` installs it, enables
  `waydroid-container.service`, and runs `waydroid init`.
- Double-clicking an `.apk` routes to `enclave-run-android`, which installs it
  (or tells you to run `enclave-appsetup android` first).
- Kernel note: Arch's stock `linux` ships binder as modules (`binder_linux`,
  `ashmem` via `android-binderfs`); if a custom kernel is used later, ensure
  binderfs is present.

## Why some things are opt-in, not in the ISO
`mkarchiso` can only install from pacman repos (not the AUR), and a live/install
ISO should stay small. So AUR-only runtimes (Waydroid, `umu-launcher`/`proton-ge`)
and heavy ones (Steam) are installed on the running system by `enclave-appsetup`,
which bootstraps an AUR helper (`paru`) as needed. A future signed `[enclave]`
repo can move these back into the image for a fully offline install.

## Launchers
| File type | Handler | Backend |
|---|---|---|
| `.exe`, `.msi` | `enclave-run-windows` | Wine |
| `.apk` | `enclave-run-android` | Waydroid |
| `.flatpakref`/Flathub | software center | Flatpak |
