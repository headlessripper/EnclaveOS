#!/usr/bin/env bash
# Enclave OS — Phase 0 (Arch) static assertions.
# Validates the archiso overlay + build script without needing Arch/mkarchiso,
# so it runs anywhere (CI, the Windows host via Git Bash, or WSL).
# Run from the repo root:  bash tests/phase0-asserts.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fail=0
pass() { echo "PASS $1"; }
bad()  { echo "FAIL $1"; fail=1; }

has() { # file  pattern  name
  if [ -f "$1" ] && grep -qE "$2" "$1"; then pass "$3"; else bad "$3 ($1 !~ $2)"; fi
}
exists() { if [ -e "$1" ]; then pass "$2"; else bad "$2 (missing $1)"; fi; }

A="arch"; O="$A/overlay"; AIR="$O/airootfs"

# --- identity ---
has "$A/profiledef.overrides" '^iso_name=enclave'            "iso name = enclave"
has "$A/profiledef.overrides" '^install_dir=enclave'         "install dir = enclave"
has "$AIR/etc/os-release"     '^ID=enclave'                  "os-release ID = enclave"
has "$AIR/etc/os-release"     'NAME="Enclave OS"'            "os-release NAME = Enclave OS"
has "$AIR/etc/hostname"       '^enclave$'                    "hostname = enclave"

# --- packages / repos ---
has "$O/packages.x86_64.extra" '^sddm$'                      "pkg: sddm"
has "$O/packages.x86_64.extra" '^xfce4-session$'            "pkg: xfce4-session (XFCE desktop)"
has "$O/packages.x86_64.extra" '^networkmanager$'            "pkg: networkmanager"
has "$O/pacman.conf"           '^\[multilib\]'               "pacman: multilib enabled"
# KDE/Plasma must be gone (Wayland-only, black-screens on VMware).
if grep -qE '^(plasma-desktop|plasma-workspace|kwin)$' "$O/packages.x86_64.extra"; then
  bad "Plasma packages must not be present (Wayland-only, VM black screen)"
else
  pass "no Plasma/KWin packages"
fi

# --- live session wiring ---
exists "$AIR/usr/local/bin/enclave-live-setup.sh"            "live-setup script present"
has "$AIR/etc/systemd/system/enclave-live-setup.service" 'enclave-live-setup.sh' "live-setup unit runs script"
has "$AIR/etc/sddm.conf.d/10-enclave-autologin.conf" '^User=enclave'   "sddm autologin user = enclave"
# XFCE is an X11 desktop — renders reliably on VMware (no Wayland black screen).
has "$AIR/etc/sddm.conf.d/10-enclave-autologin.conf" '^Session=xfce\.desktop' "autologin uses the XFCE session"
has "$O/packages.x86_64.extra" '^xorg-server$'              "pkg: xorg-server (X11)"
has "$O/packages.x86_64.extra" '^xf86-input-libinput$'      "pkg: xf86-input-libinput (X input)"
has "$AIR/etc/sddm.conf.d/05-enclave-theme.conf" '^DisplayServer=x11' "sddm greeter runs under X11"
# Regression guard: user creation must not inline missing groups into useradd
# (the "network" group doesn't exist on Arch and aborted the whole script,
# leaving no account to log in with). Groups are added defensively instead.
has "$AIR/usr/local/bin/enclave-live-setup.sh" 'getent group' "live-setup adds groups defensively"
if grep -qE 'useradd .*-G[ =]' "$AIR/usr/local/bin/enclave-live-setup.sh"; then
  bad "live-setup must not pass -G to useradd (missing group aborts it)"
else
  pass "live-setup does not inline groups into useradd"
fi

# --- branding assets ---
exists "$A/branding/enclave-logo.svg"                        "branding: logo svg"

# --- debloat ---
has "$O/pacman.conf"       '^NoExtract = usr/share/man'  "debloat: NoExtract man/doc"
exists "$O/packages.remove"                              "debloat: remove list present"
has "scripts/build-iso.sh" 'packages.remove'             "debloat: build strips removed pkgs"

# --- scripts are valid bash ---
if bash -n scripts/build-iso.sh; then pass "build-iso.sh parses"; else bad "build-iso.sh parse"; fi
if bash -n "$AIR/usr/local/bin/enclave-live-setup.sh"; then pass "live-setup parses"; else bad "live-setup parse"; fi

exit $fail
