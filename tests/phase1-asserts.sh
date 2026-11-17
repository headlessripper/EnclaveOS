#!/usr/bin/env bash
# Enclave OS — Phase 1 (Windows-like desktop) static assertions.
# Validates the Plasma theme overlay without a running Plasma; runs anywhere.
# Run from the repo root:  bash tests/phase1-asserts.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fail=0
pass() { echo "PASS $1"; }
bad()  { echo "FAIL $1"; fail=1; }
has()  { if [ -f "$1" ] && grep -qE "$2" "$1"; then pass "$3"; else bad "$3 ($1 !~ $2)"; fi; }
exists() { if [ -e "$1" ]; then pass "$2"; else bad "$2 (missing $1)"; fi; }

AIR="arch/overlay/airootfs"
LNF="$AIR/usr/share/plasma/look-and-feel/org.enclave.desktop"

# --- look-and-feel package ---
has "$LNF/metadata.json" '"Id": "org.enclave.desktop"'      "look-and-feel id"
has "$LNF/contents/defaults" '^ColorScheme=EnclaveLight'    "l&f default color scheme"
has "$LNF/contents/layouts/org.kde.plasma.desktop-layout.js" 'org.kde.plasma.kickoff' "taskbar has start (kickoff)"
has "$LNF/contents/layouts/org.kde.plasma.desktop-layout.js" 'org.kde.plasma.icontasks' "taskbar has task icons"

# --- color schemes + accent ---
has "$AIR/usr/share/color-schemes/EnclaveLight.colors" 'DecorationFocus=255,122,61' "light accent = Enclave orange"
exists "$AIR/usr/share/color-schemes/EnclaveDark.colors"  "dark color scheme present"

# --- system defaults applied on first boot ---
has "$AIR/etc/xdg/kdeglobals" 'LookAndFeelPackage=org.enclave.desktop' "system default look-and-feel"
has "$AIR/etc/xdg/kdeglobals" '^AccentColor=255,122,61'     "system accent color"
exists "$AIR/usr/share/icons/Enclave/index.theme"           "Enclave icon theme present"
exists "$AIR/etc/skel/.config/autostart/enclave-firstrun.desktop" "first-run autostart present"

# --- wallpaper ---
exists "arch/branding/wallpapers/enclave-default.svg"       "default wallpaper present"

# --- SDDM login theme (Windows-familiar greeter) ---
SDDM="$AIR/usr/share/sddm/themes/enclave"
has "$SDDM/metadata.desktop" 'Type=sddm-theme'              "sddm theme metadata"
has "$SDDM/metadata.desktop" '^MainScript=Main.qml'         "sddm theme main script"
exists "$SDDM/Main.qml"                                      "sddm theme Main.qml present"
has "$SDDM/Main.qml" 'sddm\.login'                          "sddm theme performs login"
has "$SDDM/theme.conf" 'accentColor=#FF7A3D'               "sddm theme uses Enclave accent"
has "$AIR/etc/sddm.conf.d/05-enclave-theme.conf" '^Current=enclave' "sddm uses the Enclave theme"
exists "arch/branding/wallpapers/enclave-login.svg"         "login background present"

# --- lock screen matches the login ---
has "$AIR/etc/xdg/kscreenlockerrc" 'enclave-login\.svg'     "lock screen uses Enclave wallpaper"

# --- window bubble (frameless part 1) ---
exists "$AIR/usr/share/kwin/scripts/enclave-bubble/metadata.json"       "bubble kwin script metadata"
has "$AIR/usr/share/kwin/scripts/enclave-bubble/contents/code/main.js" 'noBorder = true' "frameless strips decorations"

# --- scripts parse ---
if bash -n "$AIR/usr/local/bin/enclave-firstrun.sh"; then pass "firstrun parses"; else bad "firstrun parse"; fi

exit $fail
