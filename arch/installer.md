# Enclave OS — graphical installer (Calamares)

Phase 4: a graphical installer so Enclave can be installed to disk and booted
like a normal OS, instead of only running live from the ISO.

## Why Calamares (and why it's built, not pulled)

Calamares is the Windows-familiar graphical installer used by most Arch-based
distros (EndeavourOS, Garuda, ArcoLinux…). There is **no trustworthy prebuilt
Calamares in a pacman repo** for plain Arch:

- EndeavourOS ships only the *PKGBUILD*, not the compiled package.
- Chaotic-AUR doesn't carry it.

But every Calamares dependency (`kpmcore`, `kcoreaddons`, `libpwquality`,
`qt6-declarative`, `qt6-svg`, `yaml-cpp`) **is** in the official repos. So the
build compiles just Calamares from the AUR into a local `file://` repo that
`mkarchiso` installs from — no third-party repo or key trust required. See the
"Calamares installer" step in [`../scripts/build-iso.sh`](../scripts/build-iso.sh).
This adds a one-time ~10 min compile to the build.

## What the installer does

Launched from **Install Enclave OS** (pinned in Start) →
[`enclave-install`](overlay/airootfs/usr/local/bin/enclave-install), which runs
Calamares as root through the live user's passwordless sudo and passes the
Wayland display along (`pkexec` strips the session environment, so Calamares
would have no display to open on). The module sequence
([`overlay/airootfs/etc/calamares/settings.conf`](overlay/airootfs/etc/calamares/settings.conf)):

1. **partition** — erase-disk by default (manual still available); 512M EFI + ext4.
2. **unpackfs** — copies the live squashfs (`/run/archiso/bootmnt/enclave/x86_64/airootfs.sfs`) to the target.
3. **users** — creates the real account (sudo via `wheel`; no autologin).
3b. **netinstall** — downloads the rest of the apps into the new system (see below).
4. **initcpio / grub / bootloader** — regenerates initramfs and installs GRUB (UEFI) with the
   Enclave GRUB theme; the menu stays hidden unless Esc is held.
5. **cleanup** (shellprocess, in chroot) — strips the live-only bits so the
   installed system boots to the Enclave greeter:
   - removes the live autologin drop-in and passwordless-sudo file,
   - disables/removes the live setup services,
   - deletes the live `enclave` user,
   - removes Calamares and its launchers.

The Enclave SDDM **login theme** is kept (it lives in `05-enclave-theme.conf`,
separate from the live-only `10-enclave-autologin.conf`), so the installed
system shows the Enclave greeter.

## Netinstall: a smaller ISO, the same desktop

The live ISO carries the desktop preview only. Apps the live session doesn't
need are listed in [`overlay/packages.netinstall`](overlay/packages.netinstall)
(Thunderbird, Media Player, the sound mixer, Wine and the 32-bit libraries,
Flatpak, the full Noto fonts, Python tooling, manual pages) and the installer
downloads them from the Arch mirrors into the new system. So **the installer
needs internet** (`welcome.conf` makes it a requirement).

- `build-iso.sh` generates `etc/calamares/modules/packages.conf` from the
  list and refuses a package that is also in `packages.x86_64.extra`.
- `shellprocess@netprep` → [`enclave-netinstall-prep`](overlay/airootfs/usr/local/bin/enclave-netinstall-prep):
  lends the target the live DNS, copies the mirror list (falls back to
  Arch's CDN), enables `[multilib]` and fills the pacman keyring.
- `packages` installs the list (pacman, 4 retries).
- `shellprocess@netdone` → [`enclave-netinstall-finish`](overlay/airootfs/usr/local/bin/enclave-netinstall-finish):
  puts the target's `resolv.conf` back and deletes the live preview's
  stand-ins (listed in `usr/share/enclave/netinstall/preview-files`).

The live desktop looks the same as before: Thunderbird and Media Player are
still in Start and the dock, as small stand-ins that say the app comes with
Enclave OS once it is installed.

## Netboot: the few-MB ISO

`enclave-netboot.iso` (~2.5 MB, [`tools/make-netboot-iso.sh`](../tools/make-netboot-iso.sh))
holds only iPXE. It gets an address over a wired network, downloads
`enclave-vmlinuz` and `enclave-initramfs.img` over HTTPS from the GitHub
Release, and the live initramfs's `enclave_http` hook
([`etc/initcpio/hooks/enclave_http`](overlay/airootfs/etc/initcpio/hooks/enclave_http))
downloads `enclave-airootfs.sfs` into RAM and boots it. It bind-mounts the
download onto `/run/archiso/bootmnt`, so the installer's unpackfs finds the
image where it always does. Needs UEFI, wired internet and 4 GB+ of memory.
The build makes it from the full ISO (step 10); CI publishes all four files.
The installed system drops the hook (cleanup).

## Look: Enclave Ember

The installer wears Enclave's own interface
([`branding/enclave/`](overlay/airootfs/etc/calamares/branding/enclave/)):

- `calamares-sidebar.qml` — the step rail (mark + "Enclave OS / Installer",
  ember checks for finished steps, an ember pill for the current one).
- `stylesheet.qss` — dark Ember for every page: rounded fields, ember focus,
  pill buttons (Next is ember), Ember progress bar, summary cards.
- `show.qml` — the full-bleed slideshow during the copy.
- `welcome.svg` — the welcome-page art.

Navigation stays the Calamares *widget* footer (styled by the QSS): a QML
footer can't take keyboard focus, which would lose Alt+N / Alt+B / Alt+I.

## Known caveats

- The account names `enclave`, `live`, `builder`, `root`, `nobody` are refused
  (`users.conf`): cleanup deletes the live `enclave` user, so a same-named
  account would lose its home.
- The installer flow can only be fully verified by running an install in a VM;
  expect to iterate on module specifics after the first boot test.
