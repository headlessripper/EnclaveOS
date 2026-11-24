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
has "$XML/xfce4-panel.xml" 'value="enclave-start\.desktop"'  "panel has the Enclave Start button"
has "$XML/xfce4-panel.xml" 'value="docklike"'                "taskbar has pinned + running apps (Docklike)"
has "$XML/xfce4-panel.xml" '"clock"'                         "panel has a clock"
has "$XML/xfce4-panel.xml" 'showdesktop'                     "taskbar has a show-desktop corner"
has "$XML/xfce4-panel.xml" 'name="plugin-1" type="string" value="enclave-balancer"' "taskbar truly centred (balancer is the first plugin)"
exists "arch/plugins/enclave-balancer/enclave-balancer.c"   "centring plugin source present"
has "arch/plugins/enclave-balancer/enclave-balancer.desktop" '^X-XFCE-Module=enclave-balancer$' "centring plugin module name"
has "scripts/build-iso.sh" 'libxfce4panel-2.0'              "build compiles the Enclave panel plugins"
has "arch/overlay/packages.x86_64.extra" '^xfce4-docklike-plugin$' "pkg: xfce4-docklike-plugin"
has "$AIR/etc/xdg/xfce4/panel/docklike.rc" '^pinned=.*zen'   "taskbar pins Zen Browser"

# --- Start menu (Enclave's own: pinned grid, Recommended, All apps, search) ---
ST="$AIR/usr/local/bin/enclave-start"
exists "$ST"                                                  "Enclave Start menu present"
has "$ST" 'Recommended'                                       "start menu: Recommended section"
has "$ST" 'All apps'                                          "start menu: All apps list"
has "$ST" 'enclave-applications\.menu'                        "start menu uses the de-cluttered app list"
has "$ST" 'start-defaults\.json'                              "start menu: default pins"
has "$ST" 'set_prgname\("enclave-start"\)'                      "start menu WM_CLASS Enclave-start (picom rule match)"
exists "$AIR/usr/share/enclave/start-defaults.json"           "default pinned apps present"
has "$AIR/usr/local/bin/enclave-start-toggle" 'org\.gtk\.Actions\.Activate' "Start button toggles the running menu"
has "$AIR/etc/skel/.config/autostart/enclave-start.desktop" 'enclave-start --background' "start menu preloads at login"
has "$XFC/panel/launcher-3/enclave-start.desktop" '^Icon=/usr/share/enclave/enclave-logo\.svg' "start button uses the Enclave logo"
has "$XML/xfce4-panel.xml" 'name="plugin-3" type="string" value="launcher"' "Start button is panel plugin 3 (matches launcher-3/)"
has "$AIR/etc/skel/.config/picom.conf" "class_g = 'Enclave-start'" "picom rounds the Start menu"
exists "$AIR/usr/share/enclave/menus/enclave-applications.menu" "de-cluttered app list present"
has "$AIR/usr/share/enclave/menus/enclave-applications.menu" '<Category>X-XFCE-SettingsDialog</Category>' "settings panels folded into Settings"
if grep -q '^xfce4-whiskermenu-plugin$' arch/overlay/packages.x86_64.extra; then
  bad "Whisker menu no longer shipped (replaced by enclave-start)"
else
  pass "Whisker menu no longer shipped (replaced by enclave-start)"
fi
has "$AIR/usr/local/share/applications/org.xfce.ristretto.desktop" '^Name=Photos$' "image viewer branded 'Photos'"
has "$AIR/usr/local/share/applications/io.github.celluloid_player.Celluloid.desktop" '^Name=Media Player$' "video player branded 'Media Player'"

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
has "$XML/xfce4-keyboard-shortcuts.xml" 'enclave-start-toggle'   "Windows key opens Start"
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
