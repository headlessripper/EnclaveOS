#!/usr/bin/env bash
# Enclave OS — Phase 4 (Calamares installer) static assertions.
# Validates the installer overlay + build wiring without running Calamares.
# Run from the repo root:  bash tests/phase4-asserts.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fail=0
pass() { echo "PASS $1"; }
bad()  { echo "FAIL $1"; fail=1; }
has()  { if [ -f "$1" ] && grep -qE "$2" "$1"; then pass "$3"; else bad "$3 ($1 !~ $2)"; fi; }
exists() { if [ -e "$1" ]; then pass "$2"; else bad "$2 (missing $1)"; fi; }

AIR="arch/overlay/airootfs"
CAL="$AIR/etc/calamares"

# --- package + build wiring ---
has "arch/overlay/packages.x86_64.extra" '^calamares$'        "pkg: calamares"
has "arch/overlay/packages.x86_64.extra" '^grub$'             "pkg: grub (target bootloader)"
has "arch/overlay/packages.x86_64.extra" '^squashfs-tools$'   "pkg: squashfs-tools (unpackfs)"
has "scripts/build-iso.sh" 'aur.archlinux.org/calamares'      "build compiles Calamares from AUR"
has "scripts/build-iso.sh" '\[enclave-local\]'                "build registers a local repo"
has "scripts/build-iso.sh" 'repo-add'                         "build adds pkg to local repo"
has ".github/workflows/build-iso.yml" 'base-devel'           "CI installs base-devel (makepkg)"

# --- Calamares config ---
exists "$CAL/settings.conf"                                   "calamares settings.conf"
has "$CAL/settings.conf" 'branding: enclave'                 "calamares uses Enclave branding"
has "$CAL/settings.conf" 'shellprocess@cleanup'             "install sequence runs cleanup"
has "$CAL/modules/unpackfs.conf" 'enclave/x86_64/airootfs\.sfs' "unpackfs points at the live squashfs"
has "$CAL/modules/bootloader.conf" 'efiBootLoader: "grub"'  "bootloader = grub (UEFI)"
has "$CAL/modules/users.conf" 'sudoersGroup: wheel'         "installed user gets sudo via wheel"
# Regression guard: don't repeat the missing-"network"-group bug on the target.
if grep -qE '^\s*-\s*network\s*$' "$CAL/modules/users.conf"; then
  bad "users.conf must not add the non-existent 'network' group"
else
  pass "users.conf avoids the missing 'network' group"
fi
has "$CAL/modules/displaymanager.conf" 'sddm'               "installed display manager = sddm"

# --- cleanup strips the live-only bits ---
has "$CAL/modules/shellprocess-cleanup.conf" '10-enclave-autologin\.conf' "cleanup removes live autologin"
has "$CAL/modules/shellprocess-cleanup.conf" 'userdel -rf enclave'        "cleanup removes the live user"
has "$CAL/modules/shellprocess-cleanup.conf" 'pacman -R --noconfirm calamares' "cleanup removes the installer"

# --- branding + launcher ---
has "$CAL/branding/enclave/branding.desc" 'productName:\s+Enclave OS' "branding names Enclave OS"
exists "$CAL/branding/enclave/show.qml"                       "installer slideshow present"
has "$AIR/usr/share/applications/enclave-install.desktop" 'Exec=pkexec calamares' "Install launcher (menu)"
exists "$AIR/etc/skel/Desktop/enclave-install.desktop"       "Install launcher on live desktop"

exit $fail
