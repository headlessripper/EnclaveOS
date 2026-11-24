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
for s in Wallpaper Taskbar StartMenu Bubble; do
  exists "$SH/qml/$s.qml"                             "surface: $s"
  has "$SH/qml/$s.qml" 'org\.kde\.layershell'         "$s is a layer-shell surface"
done
has "$SH/qml/Bubble.qml" 'activeMinimize'             "bubble controls the active window (Wayland)"
has "$SH/qml/Taskbar.qml" 'anchors\.centerIn: parent' "taskbar items truly centred"
has "$SH/qml/StartMenu.qml" 'Recommended'             "Start: Recommended section"
has "$SH/src/appregistry.cpp" 'enclave-applications\.menu' "apps from .desktop entries + Enclave menu rules"
if grep -rqE '#[0-9A-Fa-f]{6}' "$SH/qml/Taskbar.qml" "$SH/qml/StartMenu.qml" "$SH/qml/Bubble.qml"; then
  bad "surfaces use theme tokens, not hard-coded colours"
else
  pass "surfaces use theme tokens, not hard-coded colours"
fi
has "arch/overlay/airootfs/usr/share/enclave/start-defaults.json" '"taskbar"' "default taskbar pins"

# --- session: labwc underneath, selectable from SDDM ---
has "$SES/usr/share/wayland-sessions/enclave.desktop" '^Exec=/usr/bin/enclave-session$' "SDDM: Enclave (Wayland) session"
has "$SES/usr/bin/enclave-session" 'labwc'            "session runs labwc"
has "$SES/usr/bin/enclave-session" 'WLR_RENDERER=pixman' "software-render fallback (VMs without GPU)"
has "$SES/usr/share/enclave/labwc/autostart" 'enclave-shell-run' "shell autostarts (with crash restart)"
has "$SES/usr/bin/enclave-shell-run" 'enclave-shell'  "crash-restart wrapper"
has "$SES/usr/share/enclave/labwc/rc.xml" 'Super_L'   "Windows key opens Start"
has "$SES/usr/share/enclave/labwc/rc.xml" 'Enclave-Ember' "windows use the Ember frame theme"
has "$SES/usr/share/themes/Enclave-Ember/labwc/themerc" 'FF7A1A' "Ember orange focus cues"
has "$SES/usr/share/xdg-desktop-portal/enclave-portals.conf" 'wlr' "portals for screenshots/screen share"

# --- build + packages ---
has "scripts/build-iso.sh" 'compiling Enclave Shell'  "build compiles Enclave Shell"
has "scripts/build-iso.sh" '/usr/bin/\$f" 755|add_file_perm "/usr/bin/' "shell executables get 0755"
for p in labwc xorg-xwayland layer-shell-qt qt6-declarative qt6-wayland xdg-desktop-portal-wlr; do
  has "arch/overlay/packages.x86_64.extra" "^$p\$" "pkg: $p"
done
has "scripts/build-iso-docker.sh" 'layer-shell-qt'    "docker build has shell deps"
has ".github/workflows/build-iso.yml" 'layer-shell-qt' "CI build has shell deps"

exit $fail
