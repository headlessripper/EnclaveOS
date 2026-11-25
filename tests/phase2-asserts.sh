#!/usr/bin/env bash
# Enclave OS — Phase 2 (universal apps) static assertions. Runs anywhere.
# Run from the repo root:  bash tests/phase2-asserts.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fail=0
pass() { echo "PASS $1"; }
bad()  { echo "FAIL $1"; fail=1; }
has()  { if [ -f "$1" ] && grep -qE "$2" "$1"; then pass "$3"; else bad "$3 ($1 !~ $2)"; fi; }
exists() { if [ -e "$1" ]; then pass "$2"; else bad "$2 (missing $1)"; fi; }
parses() { if bash -n "$1"; then pass "$2 parses"; else bad "$2 parse"; fi; }

AIR="arch/overlay/airootfs"
BIN="$AIR/usr/local/bin"
# Downloaded by the installer (netinstall), not on the live ISO.
P="arch/overlay/packages.netinstall"

# --- packages ---
has "$P" '^flatpak$'   "netinstall: flatpak"
has "$P" '^wine$'      "netinstall: wine"
has "$P" '^winetricks$' "netinstall: winetricks"
has "$P" '^lib32-mesa$' "netinstall: lib32 runtime (Proton/Wine)"

# --- launchers ---
exists "$BIN/enclave-run-windows"  "windows launcher present"
exists "$BIN/enclave-run-android"  "android launcher present"
exists "$BIN/enclave-appsetup"     "app-compat setup present"
parses "$BIN/enclave-run-windows"  "windows launcher"
parses "$BIN/enclave-run-android"  "android launcher"
parses "$BIN/enclave-appsetup"     "app-compat setup"

# --- file-type handlers ---
has "$AIR/usr/share/applications/enclave-windows-app.desktop" 'MimeType=.*x-ms-dos-executable' "exe handler MimeType"
has "$AIR/usr/share/applications/enclave-android-app.desktop" 'vnd.android.package-archive'     "apk handler MimeType"
has "$AIR/etc/xdg/mimeapps.list" 'x-ms-dos-executable=enclave-windows-app.desktop' "exe default association"
has "$AIR/etc/xdg/mimeapps.list" 'android.package-archive=enclave-android-app.desktop' "apk default association"

# --- flathub ---
exists "$AIR/usr/local/bin/enclave-flathub.sh"                   "flathub script present"
has "$AIR/etc/systemd/system/enclave-flathub.service" 'enclave-flathub.sh' "flathub unit"
has "scripts/build-iso.sh" 'enclave-flathub.service' "build enables flathub service"

exit $fail
