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
has "$XML/xfce4-panel.xml" 'whiskermenu'                            "taskbar has a Start button"
has "$XML/xfce4-panel.xml" 'expand" type="bool" value="true"'      "taskbar centres Start+apps (expanding spacers)"
has "$AIR/etc/skel/.config/gtk-3.0/gtk.css" 'xfce4-panel'          "taskbar is styled (gtk.css)"
has "$XML/xfce4-panel.xml" 'p=8'                                    "taskbar is at the bottom"
has "$XML/xfce4-desktop.xml" 'show-filesystem" type="bool" value="false"' "no Linux 'File System' desktop icon"

# --- wallpaper ---
has "$XML/xfce4-desktop.xml" 'enclave-default\.svg'         "desktop wallpaper = Enclave"
exists "arch/branding/wallpapers/enclave-default.svg"       "default wallpaper present"

# --- Enclave Files (Thunar) + picom (Hyprland look) ---
has "$XML/thunar.xml" 'ThunarShortcutsPane'                "Enclave Files has a Places sidebar"
has "$XML/thunar.xml" 'misc-single-click" type="bool" value="false"' "Enclave Files uses double-click"
has "$AIR/etc/skel/.local/share/applications/thunar.desktop" '^Name=Files' "file manager branded 'Files'"
exists "$AIR/etc/skel/.config/Thunar/uca.xml"              "Enclave Files custom actions"
has "arch/overlay/packages.x86_64.extra" '^picom$'         "pkg: picom (Hyprland-style compositor)"
has "$XML/xfwm4.xml" 'use_compositing" type="bool" value="false"' "xfwm4 compositor off (picom takes over)"
has "$AIR/etc/skel/.config/picom.conf" 'blur-method'       "picom: blur enabled"
has "$AIR/etc/skel/.config/picom.conf" 'corner-radius'     "picom: rounded corners"
exists "$AIR/etc/skel/.config/autostart/picom.desktop"     "picom autostarts"

# --- signature floating bubble ---
exists "$AIR/usr/local/bin/enclave-bubble"                 "floating bubble app present"
has "$AIR/usr/local/bin/enclave-bubble" 'wmctrl|xdotool'   "bubble controls the active window"
exists "$AIR/etc/skel/.config/autostart/enclave-bubble.desktop" "bubble autostarts"
has "arch/overlay/packages.x86_64.extra" '^python-gobject$' "pkg: python-gobject (bubble GTK)"
has "arch/overlay/packages.x86_64.extra" '^wmctrl$'        "pkg: wmctrl (bubble window control)"
has "arch/overlay/packages.x86_64.extra" '^xdotool$'       "pkg: xdotool (bubble window control)"

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
has "$SDDM/theme.conf" 'accentColor=#ff6b1a'               "sddm theme uses Enclave accent"
has "$AIR/etc/sddm.conf.d/05-enclave-theme.conf" '^Current=enclave' "sddm uses the Enclave theme"
exists "arch/branding/wallpapers/enclave-login.svg"         "login background present"

exit $fail
