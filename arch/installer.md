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
