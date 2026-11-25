#!/usr/bin/env bash
# Enclave OS — Phase 5: Enclave Shell (own Wayland desktop) static assertions.
# Run from the repo root:  bash tests/phase5-asserts.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fail=0
pass() { echo "PASS $1"; }
bad()  { echo "FAIL $1"; fail=1; }
has()  { if [ -f "$1" ] && grep -qE -- "$2" "$1"; then pass "$3"; else bad "$3 ($1 !~ $2)"; fi; }
exists() { if [ -e "$1" ]; then pass "$2"; else bad "$2 (missing $1)"; fi; }

SH="desktop/shell"
SES="desktop/session/rootfs"
TOK="desktop/design-system/tokens/ember.json"

# --- Enclave Ember design tokens (orange identity, adaptive light/dark) ---
exists "$TOK"                                         "Ember tokens present"
if python3 -c "import json,sys; json.load(open('$TOK'))" 2>/dev/null || python -c "import json,sys; json.load(open('$TOK'))" 2>/dev/null; then
  pass "Ember tokens are valid JSON"
else
  bad "Ember tokens are valid JSON"
fi
has "$TOK" '"ember": +"#FF7A1A"'                      "brand: Ember Orange #FF7A1A"
has "$TOK" '"background": +"#101114"'                 "dark: Obsidian background"
has "$TOK" '"background": +"#F7F6F3"'                 "light: Porcelain background"
has "$TOK" '"surface": +"#1A1C21"'                    "dark: Graphite surface"
has "$TOK" '"elevated": +"#EAE8E2"'                   "light: Warm Grey elevated"
if grep -qiE '#8B5CF6|#7450D9' "$TOK"; then bad "no Aurora purple in Ember"; else pass "no Aurora purple in Ember"; fi
has "$SH/src/theme.cpp" 'design-system/ember\.json'   "shell reads the Ember tokens"

# --- shell: own surfaces, compositor-independent window management ---
exists "$SH/CMakeLists.txt"                           "shell CMake project"
has "$SH/CMakeLists.txt" 'wlr-foreign-toplevel-management' "task list via standard wlr protocol"
has "$SH/src/windowmanager.h" 'class WindowManager'   "WindowManager interface (compositor-independent)"
has "$SH/src/toplevels.h" 'public WindowManager'      "foreign-toplevel implements WindowManager"
if grep -rqE 'labwc' "$SH/src"; then bad "shell code never depends on labwc"; else pass "shell code never depends on labwc"; fi
for s in Wallpaper SearchWidget Taskbar Widgets StartMenu Bubble components/Flyout; do
  exists "$SH/qml/$s.qml"                             "surface: $s"
  has "$SH/qml/$s.qml" 'org\.kde\.layershell'         "$s is a layer-shell surface"
done
for s in ControlCenter CalendarPanel Spotlight; do
  has "$SH/qml/$s.qml" '^Flyout \{'                    "$s is a flyout surface"
done
has "$SH/qml/Bubble.qml" 'activeMinimize'             "bubble controls the active window (Wayland)"
has "$SH/qml/Bubble.qml" 'Snap left'                  "bubble snaps windows (they have no title bar)"
has "$SH/qml/Bubble.qml" 'setInputRegion'             "bubble is click-through around itself"
has "$SH/qml/Bubble.qml" 'bubble/side'                "bubble remembers where it rests"
has "$SH/qml/Bubble.qml" 'LayerShell.Window.LayerOverlay' "bubble is on top of every window (overlay layer)"
has "$SH/qml/Taskbar.qml" 'anchors\.centerIn: parent' "dock items truly centred"
has "$SH/qml/Taskbar.qml" 'allAppsRequested'          "dock ends with All apps"
# no top bar: status lives in the Now widget, search in its own widget
if [ -e "$SH/qml/TopBar.qml" ] || grep -q 'TopBar' "$SH/qml/Main.qml" "$SH/CMakeLists.txt"; then
  bad "the top bar is gone"
else
  pass "the top bar is gone"
fi
has "$SH/qml/SearchWidget.qml" 'Search anything'      "desktop search widget"
has "$SH/qml/Spotlight.qml" 'recentFiles'             "search: recent files"
has "$SH/qml/Spotlight.qml" 'Calculator|calculator'   "search: sums"
has "$SH/qml/Widgets.qml" 'showStatus'                "Now widget: time, network, battery"
has "$SH/qml/Widgets.qml" 'batteryMinutes'            "Now widget: battery time left"

# --- the dock ---
has "$SH/src/appregistry.cpp" 'm_taskbarPins\.contains' "a pinned app's windows group under its pin"
has "$SH/qml/components/DockItem.qml" 'windowCount'    "dock: one dot per window"
has "$SH/qml/components/WindowPeek.qml" 'closeRequested' "dock: hover window list with close"
has "$SH/qml/Taskbar.qml" 'moveTaskbarPin'            "dock: drag pins to reorder"
has "$SH/qml/Taskbar.qml" 'cycleGroup'                "dock: scroll steps through windows"
has "$SH/qml/Taskbar.qml" 'user-trash-full'           "dock: Trash shows full / empty"
has "$SH/qml/Taskbar.qml" 'dock/autohide'             "dock: auto-hide option"
has "$SH/qml/Taskbar.qml" 'setInputRegion'            "dock: clicks pass through beside the island"

# --- Enclave Settings ---
exists "$SES/usr/bin/enclave-settings"                "enclave-settings launcher"
has "$SES/usr/bin/enclave-settings" 'enclave-shell --settings' "Settings runs from the shell binary"
has "$SH/src/main.cpp" 'runSettings'                  "shell has a Settings mode"
has "$SH/src/main.cpp" 'enclave-settings-'            "Settings is single-instance"
for p in Network Sound Displays Appearance Desktop Notifications Power Activity Storage DateTime Keyboard About; do
  exists "$SH/qml/settings/${p}Page.qml"              "Settings page: $p"
done
has "$SH/qml/Main.qml" 'reload-settings'              "shell applies Settings changes at once"
has "$SES/usr/share/applications/enclave-settings.desktop" '^Exec=enclave-settings$' "Settings entry opens the app"
has "$SES/usr/share/applications/enclave-activity.desktop" 'page activity' "Activity (task manager) entry"
has "$SES/usr/share/enclave/labwc/rc.xml" 'C-S-Escape.*page activity' "Ctrl+Shift+Esc opens Activity"
if grep -rqE 'nm-connection-editor"|"wdisplays|"pavucontrol"|xfce4-taskmanager' "$SH/qml/ControlCenter.qml" "$SH/qml/Widgets.qml"; then
  bad "Control Center and widgets open Settings, not old tools"
else
  pass "Control Center and widgets open Settings, not old tools"
fi

# --- Enclave Terminal ---
TERM_DIR="desktop/terminal"
exists "$TERM_DIR/CMakeLists.txt"                      "terminal CMake project"
has "$TERM_DIR/CMakeLists.txt" 'qtermwidget6'          "terminal built on QTermWidget"
exists "$TERM_DIR/schemes/Enclave-Dark.colorscheme"    "terminal: Enclave Dark colours"
exists "$TERM_DIR/schemes/Enclave-Light.colorscheme"   "terminal: Enclave Light colours"
has "$TERM_DIR/schemes/Enclave-Dark.colorscheme" '^Color=16,17,20$' "terminal dark ground is Obsidian"
has "$TERM_DIR/src/main.cpp" 'working-directory'       "terminal: --working-directory"
has "$TERM_DIR/src/main.cpp" '"-x"'                    "terminal: -x PROGRAM ARGS (terminal apps)"
has "$TERM_DIR/src/terminalwindow.cpp" 'startSystemMove' "terminal: the tab strip is the title bar"
has "$TERM_DIR/src/terminalwindow.cpp" 'appearance/mode' "terminal follows Enclave light / dark"
has "scripts/build-iso.sh" 'compiling Enclave Terminal' "build compiles Enclave Terminal"
has "$SH/src/appregistry.cpp" 'enclave-terminal -x'    "terminal apps open in Enclave Terminal"
has "$SH/src/files.cpp" '"enclave-terminal"' "Files: Open in Terminal"
has "arch/overlay/airootfs/etc/xdg/xfce4/helpers.rc" 'TerminalEmulator=enclave-terminal' "exo's terminal is Enclave Terminal"
has "arch/overlay/airootfs/usr/share/enclave/start-defaults.json" 'enclave-terminal\.desktop' "Terminal pinned"
if grep -rqE 'xfce4-terminal' "$SES/usr/share/enclave" arch/overlay/airootfs/usr/share/enclave/start-defaults.json      "$SH/src" "$SH/qml"; then
  bad "no xfce4-terminal left in the session"
else
  pass "no xfce4-terminal left in the session"
fi
for p in qtermwidget ttf-jetbrains-mono wlr-randr power-profiles-daemon; do
  has "arch/overlay/packages.x86_64.extra" "^$p\$" "pkg: $p"
done
has "$SH/qml/StartMenu.qml" 'Recommended'             "Start: Recommended section"
has "$SH/qml/StartMenu.qml" 'Apps\.categories'        "Start: category rail"
has "$SH/qml/Wallpaper.qml" 'Apps\.desktopPins'       "desktop icons only when the user adds them"
has "$SH/src/appregistry.h" 'pinDesktop'              "apps can be added to / removed from the desktop"
has "$SH/qml/Widgets.qml" 'System\.stats'             "widgets show live system figures"
has "$SH/src/system.cpp" 'System::query'              "status queries never block the shell"
has "$SH/src/appregistry.cpp" 'enclave-applications\.menu' "apps from .desktop entries + Enclave menu rules"
if grep -rqE '#[0-9A-Fa-f]{6}' "$SH/qml/"*.qml "$SH/qml/components/"*.qml; then
  bad "surfaces use theme tokens, not hard-coded colours"
else
  pass "surfaces use theme tokens, not hard-coded colours"
fi
has "arch/overlay/airootfs/usr/share/enclave/start-defaults.json" '"taskbar"' "default taskbar pins"

# --- session: Hyprland underneath (no fallback), selectable from SDDM ---
has "$SES/usr/share/wayland-sessions/enclave.desktop" '^Exec=/usr/bin/enclave-session$' "SDDM: Enclave (Wayland) session"
has "$SES/usr/bin/enclave-session" '^exec Hyprland'    "session runs Hyprland"
if grep -q 'labwc' <(grep -v '^#' "$SES/usr/bin/enclave-session"); then bad "no labwc fallback in the session"; else pass "no labwc fallback in the session"; fi
has "scripts/build-iso.sh" 'rm -rf "\$AIR/usr/share/enclave/labwc"' "labwc config left out of the ISO"
has "$SES/usr/share/enclave/hypr/hyprland.lua" 'enclave\.minimize|function enclave' "Hyprland config: the Enclave bridge"
has "$SES/usr/share/enclave/hypr/hyprland.lua" 'enclave-shell-run' "Hyprland autostarts the shell"
has "arch/overlay/packages.x86_64.extra" '^hyprland$'  "pkg: hyprland"
has "$SES/usr/share/enclave/labwc/autostart" 'enclave-shell-run' "shell autostarts (with crash restart)"
has "$SES/usr/bin/enclave-shell-run" 'enclave-shell'  "crash-restart wrapper"
has "$SES/usr/share/enclave/labwc/rc.xml" 'Super_L'   "Windows key opens Start"
has "$SES/usr/share/enclave/labwc/rc.xml" 'Enclave-Ember' "windows use the Ember frame theme"
has "$SES/usr/share/themes/Enclave-Ember/labwc/themerc" 'FF7A1A' "Ember orange focus cues"
has "$SES/usr/share/enclave/labwc/rc.xml" 'decorations="border" forceSSD="yes"' "every window's title bar and frame stripped"
has "$SES/usr/share/enclave/labwc/rc.xml" '<maximizedDecoration>none' "maximised windows are frameless"
has "$SES/usr/share/themes/Enclave-Ember/labwc/themerc" '26262E' "Enclave frame: Reclip-style hairline"
has "arch/overlay/packages.x86_64.extra" '^wtype$'     "pkg: wtype (bubble snap/move)"
has "$SES/usr/share/xdg-desktop-portal/enclave-portals.conf" 'wlr' "portals for screenshots/screen share"

# --- build + packages ---
has "scripts/build-iso.sh" 'compiling Enclave Shell'  "build compiles Enclave Shell"
has "scripts/build-iso.sh" '/usr/bin/\$f" 755|add_file_perm "/usr/bin/' "shell executables get 0755"
if grep -q '^labwc$' arch/overlay/packages.x86_64.extra; then bad "labwc not on the ISO"; else pass "labwc not on the ISO"; fi
for p in hyprland xorg-xwayland layer-shell-qt qt6-declarative qt6-wayland xdg-desktop-portal-wlr; do
  has "arch/overlay/packages.x86_64.extra" "^$p\$" "pkg: $p"
done
has "scripts/build-iso-docker.sh" 'layer-shell-qt'    "docker build has shell deps"
has ".github/workflows/build-iso.yml" 'layer-shell-qt' "CI build has shell deps"

# --- Enclave Files (replaces Thunar) ---
has "$SH/src/main.cpp" 'runFiles'                      "enclave-shell --files mode"
has "$SH/CMakeLists.txt" 'qml/Files\.qml'              "Files UI is built in"
has "$SES/usr/bin/enclave-files" 'enclave-shell --files' "enclave-files launcher"
has "arch/overlay/airootfs/etc/xdg/mimeapps.list" '^inode/directory=enclave-files\.desktop' "folders open in Files"
has "$SH/src/files.cpp" 'moveToTrash'                  "Files: Move to Trash"
has "$SH/qml/Files.qml" 'asynchronous: String\(source\)\.startsWith' "icons load on the GUI thread (no crash)"
if grep -rqiE 'thunar' "$SH/qml" "$SES/usr/share/enclave/hypr" arch/overlay/airootfs/usr/share/enclave/start-defaults.json arch/overlay/airootfs/etc/xdg/mimeapps.list; then
  bad "no Thunar left in the desktop"
else
  pass "no Thunar left in the desktop"
fi
if grep -qE '^thunar' arch/overlay/packages.x86_64.extra; then bad "Thunar not on the ISO"; else pass "Thunar not on the ISO"; fi
has "$SH/src/theme.cpp" 'QFileSystemWatcher'          "Settings / Files follow light-dark live"

# --- the global rule: rounded, modern buttons ---
has "$TOK" '"small": 10'                               "small radius is 10 px"
has "$SH/qml/settings/Controls.qml" 'radius: height / 2' "Settings buttons are pills"
has "tools/enclave-gtk-patch.sh" "'round', 10px"       "GTK controls rounded to 10 px"
has "arch/themes/gtk/enclave-layer.css" 'border-radius' "GTK layer rounds the rest"
has "desktop/terminal/src/terminalwindow.cpp" 'QPushButton \{[^}]*border-radius: 15px' "Terminal buttons are pills"

# --- installer Location page: Enclave's own map ---
CAL="arch/overlay/airootfs/etc/calamares"
has "$CAL/settings.conf" '^  - localeq$'               "installer uses the QML Location page"
has "$CAL/modules/localeq.conf" '^qmlSearch: both'     "Location page loads from the branding folder"
has "$CAL/branding/enclave/localeq.qml" 'worldmap-dots\.png' "dot-matrix world map"
has "$CAL/branding/enclave/localeq.qml" 'setCurrentLocation' "map click sets the time zone"
exists "$CAL/branding/enclave/worldmap-dots.png"        "map image present"
has "$CAL/branding/enclave/zones.js" 'New_York'        "zone table present"

# --- Windows / Android apps look native ---
has "arch/overlay/airootfs/usr/local/bin/enclave-run-windows" 'Control Panel.Colors' "Wine: Ember colour scheme"
has "arch/overlay/airootfs/usr/local/bin/enclave-run-windows" 'Fonts.Replacements' "Wine: Inter fonts"
has "arch/overlay/airootfs/usr/local/bin/enclave-run-windows" 'LogPixels' "Wine: DPI follows the screen"
has "arch/overlay/airootfs/usr/local/bin/enclave-run-android" 'multi_windows true' "Android apps in their own windows"
has "arch/overlay/airootfs/usr/local/bin/enclave-run-android" 'uimode night' "Android follows dark / light"

# --- installed boot: Windows-like, extra options in the bubble ---
G="arch/overlay/airootfs/etc/grub.d"
has "$CAL/modules/grubcfg.conf" 'GRUB_TIMEOUT_STYLE: "hidden"' "boots straight in when Enclave is alone"
has "$CAL/modules/grubcfg.conf" 'GRUB_DISABLE_OS_PROBER: "false"' "other systems are found"
has "$G/45_enclave_options" 'submenu "More options"'   "the bubble holds the extra options"
has "$G/45_enclave_options" 'fwsetup'                  "UEFI Firmware Settings in the bubble"
has "$G/45_enclave_options" 'Advanced options for Enclave OS' "advanced options in the bubble"
has "$G/45_enclave_options" '30_os-prober'             "other systems go in the bubble"
has "arch/overlay/airootfs/usr/local/bin/enclave-grub-tidy" '10_enclave' "only Enclave's generators stay executable"
has "scripts/build-iso.sh" '/etc/grub.d/'              "grub.d scripts ship executable"

exit $fail
