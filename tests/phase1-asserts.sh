#!/usr/bin/env bash
# Enclave OS — Phase 1 (Windows-like XFCE desktop) static assertions.
# Validates the XFCE skel config + SDDM greeter without a running session.
# Run from the repo root:  bash tests/phase1-asserts.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fail=0
pass() { echo "PASS $1"; }
bad()  { echo "FAIL $1"; fail=1; }
has()  { if [ -f "$1" ] && grep -qE "$2" "$1"; then pass "$3"; else bad "$3 ($1 !~ $2)"; fi; }
exists() { if [ -e "$1" ]; then pass "$2"; else bad "$2 (missing $1)"; fi; }

AIR="arch/overlay/airootfs"
XFC="$AIR/etc/skel/.config/xfce4"
XML="$XFC/xfconf/xfce-perchannel-xml"

# --- Windows-familiar panel (bottom bar: start menu, tasklist, tray, clock) ---
has "$XML/xfce4-panel.xml" 'position.*p=8'                   "panel is at the bottom"
has "$XML/xfce4-panel.xml" 'whiskermenu'                     "panel has a start menu (Whisker)"
has "$XML/xfce4-panel.xml" 'tasklist'                        "panel has window buttons"
has "$XML/xfce4-panel.xml" '"clock"'                         "panel has a clock"
has "$XFC/panel/whiskermenu-1.rc" 'enclave-logo\.svg'       "start button uses the Enclave logo"

# --- theme (Fluent recolored to Enclave orange) + island panel ---
has "$XML/xsettings.xml" 'ThemeName" type="string" value="Enclave"' "GTK theme = Enclave (Fluent/orange)"
has "$XML/xfwm4.xml" 'theme" type="string" value="Enclave"'          "window decorations = Enclave"
has "$XML/xsettings.xml" 'IconThemeName" type="string" value="Papirus"' "icons = Papirus"
has "scripts/build-iso.sh" 'Fluent-gtk-theme'                       "build generates the Enclave (Fluent) theme"
has "$XML/xfce4-panel.xml" 'length-adjust" type="bool" value="true"' "taskbar is a content-width island"
has "$AIR/etc/skel/.config/gtk-3.0/gtk.css" 'border-radius'         "island panel is rounded (gtk.css)"
has "$XML/xfce4-desktop.xml" 'show-filesystem" type="bool" value="false"' "no Linux 'File System' desktop icon"

# --- wallpaper ---
has "$XML/xfce4-desktop.xml" 'enclave-default\.svg'         "desktop wallpaper = Enclave"
exists "arch/branding/wallpapers/enclave-default.svg"       "default wallpaper present"

# --- no KDE/Plasma leftovers in the overlay ---
if [ -d "$AIR/usr/share/plasma" ] || [ -d "$AIR/usr/share/kwin" ] || [ -f "$AIR/etc/xdg/kdeglobals" ]; then
  bad "KDE/Plasma overlay files still present"
else
  pass "no KDE/Plasma overlay leftovers"
fi

# --- SDDM login theme (Windows-familiar greeter, DE-agnostic, runs under X11) ---
SDDM="$AIR/usr/share/sddm/themes/enclave"
has "$SDDM/metadata.desktop" 'Type=sddm-theme'              "sddm theme metadata"
has "$SDDM/metadata.desktop" '^MainScript=Main.qml'         "sddm theme main script"
exists "$SDDM/Main.qml"                                      "sddm theme Main.qml present"
has "$SDDM/Main.qml" 'sddm\.login'                          "sddm theme performs login"
has "$SDDM/theme.conf" 'accentColor=#FF7A3D'               "sddm theme uses Enclave accent"
has "$AIR/etc/sddm.conf.d/05-enclave-theme.conf" '^Current=enclave' "sddm uses the Enclave theme"
exists "arch/branding/wallpapers/enclave-login.svg"         "login background present"

exit $fail
