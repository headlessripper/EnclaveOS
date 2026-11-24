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
has "$XML/xfce4-panel.xml" 'value="docklike"'                "taskbar has pinned + running apps (Docklike)"
has "$XML/xfce4-panel.xml" '"clock"'                         "panel has a clock"
has "$XML/xfce4-panel.xml" 'showdesktop'                     "taskbar has a show-desktop corner"
has "arch/overlay/packages.x86_64.extra" '^xfce4-docklike-plugin$' "pkg: xfce4-docklike-plugin"
has "$AIR/etc/xdg/xfce4/panel/docklike.rc" '^pinned=.*zen'   "taskbar pins Zen Browser"

# --- Start menu (Whisker 2.10 seeds itself from $XDG_CONFIG_DIRS defaults.rc;
#     a per-user whiskermenu-N.rc is only read when N == plugin id — that
#     mismatch shipped in alpha.10 and silently dropped the whole config) ---
WM="$AIR/etc/xdg/xfce4/whiskermenu/defaults.rc"
has "$WM" '^button-icon=/usr/share/enclave/enclave-logo\.svg'  "start button uses the Enclave logo"
has "$WM" '^position-search-alternate=false'                  "start menu: search on top"
has "$WM" '^position-profile-alternate=true'                  "start menu: profile + power at the bottom"
has "$WM" '^view-mode=0'                                      "start menu: pinned apps as an icon grid"
has "$WM" '^custom-menu-file=/usr/share/enclave/menus/enclave-applications\.menu' "start menu uses the de-cluttered app list"
exists "$AIR/usr/share/enclave/menus/enclave-applications.menu" "de-cluttered app list present"
has "$AIR/usr/share/enclave/menus/enclave-applications.menu" '<Category>X-XFCE-SettingsDialog</Category>' "settings panels folded into Settings"
if ls "$XFC"/panel/whiskermenu-*.rc >/dev/null 2>&1; then
  bad "no per-user whiskermenu-N.rc (it is ignored unless N matches the plugin id)"
else
  pass "no stray per-user whiskermenu-N.rc"
fi

# --- theme (Fluent recolored to Enclave orange) + island panel ---
has "$XML/xsettings.xml" 'ThemeName" type="string" value="Enclave"' "GTK theme = Enclave (Fluent/orange)"
has "$XML/xfwm4.xml" 'theme" type="string" value="Enclave"'          "window decorations = Enclave"
has "$XML/xsettings.xml" 'IconThemeName" type="string" value="Enclave-orange-light"' "icons = Enclave (Fluent)"
has "$XML/xsettings.xml" 'CursorThemeName" type="string" value="Enclave-cursors"' "cursor = Enclave (Fluent)"
has "$XML/xsettings.xml" 'FontName" type="string" value="Inter 10"' "UI font = Inter"
has "arch/overlay/packages.x86_64.extra" '^inter-font$'      "pkg: inter-font"
has "scripts/build-iso.sh" 'Fluent-icon-theme'               "build generates the Enclave icons + cursor"
has "scripts/build-iso.sh" 'FLUENT_GTK_REV="[0-9a-f]{40}"'  "Fluent GTK source is pinned"
has "scripts/build-iso.sh" 'show_app_icon=true'             "window frames show the app icon"
has "$XML/xfwm4.xml" 'title_alignment" type="string" value="left"' "window titles left-aligned (Windows)"
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
has "$AIR/usr/local/share/applications/thunar.desktop" '^Name=Files' "file manager branded 'Files'"
has "$AIR/usr/local/share/applications/xfce-settings-manager.desktop" '^Name=Settings$' "one 'Settings' app"
has "$XML/xfce4-desktop.xml" 'show-home" type="bool" value="false"' "clean desktop (no Home icon)"
has "$XML/xfce4-keyboard-shortcuts.xml" 'xfce4-popup-whiskermenu' "Windows key opens Start"
exists "$AIR/etc/skel/.config/Thunar/uca.xml"              "Enclave Files custom actions"
has "arch/overlay/packages.x86_64.extra" '^picom$'         "pkg: picom (Hyprland-style compositor)"
has "$XML/xfwm4.xml" 'use_compositing" type="bool" value="false"' "xfwm4 compositor off (picom takes over)"
has "$AIR/etc/skel/.config/picom.conf" 'blur-method'       "picom: blur enabled"
has "$AIR/etc/skel/.config/picom.conf" 'corner-radius'     "picom: rounded corners"
has "$AIR/etc/skel/.config/picom.conf" '^rules'             "picom: v12+ rules syntax"
has "$AIR/etc/skel/.config/autostart/picom.desktop" 'enclave-compositor' "compositor autostarts (with fallbacks)"
has "$AIR/usr/local/bin/enclave-compositor" 'use_compositing' "compositor falls back to xfwm4's" 

# --- signature floating bubble ---
exists "$AIR/usr/local/bin/enclave-bubble"                 "floating bubble app present"
has "$AIR/usr/local/bin/enclave-bubble" 'Wnck'             "bubble controls the active window (libwnck)"
has "$AIR/usr/local/bin/enclave-bubble" 'is_composited'      "bubble handles running without a compositor"
exists "$AIR/etc/skel/.config/autostart/enclave-bubble.desktop" "bubble autostarts"
has "arch/overlay/packages.x86_64.extra" '^python-gobject$' "pkg: python-gobject (bubble GTK)"
has "arch/overlay/packages.x86_64.extra" '^libwnck3$'      "pkg: libwnck3 (bubble window control)"
has "arch/overlay/packages.x86_64.extra" '^python-cairo$'  "pkg: python-cairo (bubble drawing)"

# --- default apps ---
has "arch/overlay/packages.x86_64.extra" '^zen-browser-bin$' "pkg: Zen Browser"
has "scripts/build-iso.sh" 'AUR_PKGS=[(].*zen-browser-bin'   "Zen Browser built from the AUR"
has "arch/overlay/packages.x86_64.extra" '^thunderbird$'     "pkg: Thunderbird"
has "$AIR/etc/xdg/mimeapps.list" '^x-scheme-handler/https=zen\.desktop' "Zen is the default browser"
has "$AIR/etc/xdg/mimeapps.list" '^x-scheme-handler/mailto=org\.mozilla\.Thunderbird\.desktop' "Thunderbird is the default mail app"

# --- executables really are executable in the image (mkarchiso drops file
#     modes; only profiledef file_permissions survive — alpha.10 shipped 0644) ---
has "scripts/build-iso.sh" 'file_permissions\+='           "build registers Enclave executables in file_permissions"
if find "$AIR/usr/local/bin" -name '__pycache__' | grep -q .; then
  bad "no __pycache__ in the overlay"
else
  pass "no __pycache__ in the overlay"
fi

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
