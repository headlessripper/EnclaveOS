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
has "scripts/build-iso.sh" 'AUR_PKGS=[(]calamares'           "build compiles Calamares from AUR"
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
has "$CAL/modules/shellprocess-cleanup.conf" 'getty@tty1\.service\.d'      "cleanup removes live root autologin"
has "$CAL/modules/shellprocess-cleanup.conf" '10-archiso\.conf'            "cleanup removes ssh root password login"
has "$CAL/modules/shellprocess-cleanup.conf" 'volatile-storage\.conf'      "cleanup restores a persistent journal"

# --- prepare makes the unpacked live system bootable from disk ---
# (mkarchiso empties /boot in the squashfs, and archiso.conf would put the
# find-the-live-ISO hooks into the installed initramfs.)
has "$CAL/settings.conf" 'shellprocess@prepare'                            "install sequence runs prepare"
if awk '/shellprocess@prepare/{p=NR} /- initcpiocfg/{i=NR} END{exit !(p && i && p<i)}' "$CAL/settings.conf"; then
  pass "prepare runs before initcpiocfg"
else
  bad "prepare must run before initcpiocfg"
fi
has "$CAL/modules/shellprocess-prepare.conf" '/boot/vmlinuz-linux'         "prepare installs the kernel into /boot"
has "$CAL/modules/shellprocess-prepare.conf" 'rm -f /etc/mkinitcpio\.conf\.d/archiso\.conf' "prepare drops the live initramfs hooks"
has "$CAL/modules/shellprocess-prepare.conf" 'pacman-key --populate'       "prepare sets up the pacman keyring"

# --- branding + launcher ---
has "$CAL/branding/enclave/branding.desc" 'productName:\s+Enclave OS' "branding names Enclave OS"
exists "$CAL/branding/enclave/show.qml"                       "installer slideshow present"
has "$AIR/usr/share/applications/enclave-install.desktop" '^Exec=enclave-install$' "Install launcher (menu)"
exists "$AIR/usr/local/bin/enclave-install"                    "installer wrapper present"
has "$AIR/usr/local/bin/enclave-install" 'WAYLAND_DISPLAY='    "wrapper passes the Wayland display to Calamares"
has "scripts/build-iso.sh" 'usr/local/bin/\$\(basename'   "installer wrapper is executable in the image (all of usr/local/bin)"
has "$CAL/modules/shellprocess-cleanup.conf" 'enclave-install' "installed system drops the installer wrapper"

# --- installer look: Enclave Ember UI ---
has "$CAL/branding/enclave/branding.desc" '^sidebar:\s+qml'    "custom QML step rail"
has "$CAL/branding/enclave/branding.desc" '^navigation:\s+widget' "widget navigation (keeps Alt+N/B/I)"
exists "$CAL/branding/enclave/calamares-sidebar.qml"           "step rail QML present"
lacks_() { if [ -f "$1" ] && grep -qE "$2" "$1"; then bad "$3 ($1 =~ $2)"; else pass "$3"; fi; }
lacks_ "$CAL/branding/enclave/calamares-sidebar.qml" 'Debug\.' "rail does not use Debug (undefined in 3.4)"
has "$CAL/branding/enclave/stylesheet.qss" '#view-button-next'  "Ember stylesheet styles the buttons"
has "$CAL/branding/enclave/stylesheet.qss" 'FF7A1A'             "stylesheet in Ember"
exists "$CAL/branding/enclave/welcome.svg"                     "welcome art present"
has "$CAL/modules/users.conf" 'forbidden_names:.*enclave'      "installer refuses the live account name"
has "$AIR/usr/share/enclave/start-defaults.json" 'enclave-install\.desktop' "Install pinned in Start (desktop stays clean)"

exit $fail
