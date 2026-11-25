#!/usr/bin/env bash
# Enclave OS — Phase 1 (the desktop's defaults and look) static assertions.
# XFCE is gone: the desktop is Enclave Shell on labwc (see phase5). This
# checks what surrounds it: session defaults, look (GTK, icons, cursor, font,
# wallpapers), default apps, boot screens and the SDDM greeter.
# Run from the repo root:  bash tests/phase1-asserts.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fail=0
pass() { echo "PASS $1"; }
bad()  { echo "FAIL $1"; fail=1; }
has()  { if [ -f "$1" ] && grep -qE -- "$2" "$1"; then pass "$3"; else bad "$3 ($1 !~ $2)"; fi; }
lacks() { if [ -f "$1" ] && grep -qE -- "$2" "$1"; then bad "$3 ($1 =~ $2)"; else pass "$3"; fi; }
exists() { if [ -e "$1" ]; then pass "$2"; else bad "$2 (missing $1)"; fi; }
gone() { if [ -e "$1" ]; then bad "$2 (still present: $1)"; else pass "$2"; fi; }

AIR="arch/overlay/airootfs"
PKG="arch/overlay/packages.x86_64.extra"

# --- XFCE and the old X11 desktop are gone ---
for p in xfce4-panel xfwm4 xfdesktop xfce4-session picom libwnck3 xfce4-docklike-plugin; do
  lacks "$PKG" "^$p\$" "no $p in the image"
done
gone "$AIR/etc/skel/.config/xfce4"            "no XFCE session config"
gone "$AIR/usr/local/bin/enclave-bubble"      "old GTK bubble removed (the shell has its own)"
gone "arch/plugins"                           "old XFCE panel plugins removed"

# --- session defaults ---
has "$AIR/etc/sddm.conf.d/10-enclave-autologin.conf" '^Session=enclave\.desktop' "live session = Enclave"
has "$AIR/etc/calamares/modules/displaymanager.conf" 'desktopFile: *"enclave"' "installed session = Enclave"
has "$AIR/usr/share/enclave/start-defaults.json" '"taskbar"' "default dock pins"
lacks "$AIR/usr/share/enclave/start-defaults.json" '"desktop"' "clean desktop: no default desktop icons"

# --- the look: GTK theme, Enclave Icons, cursor, font ---
has "$AIR/etc/skel/.config/gtk-3.0/settings.ini" '^gtk-icon-theme-name=Enclave$' "GTK 3 icons = Enclave Icons"
has "$AIR/etc/skel/.config/gtk-4.0/settings.ini" '^gtk-icon-theme-name=Enclave$' "GTK 4 icons = Enclave Icons"
has "$AIR/usr/share/glib-2.0/schemas/90_enclave.gschema.override" "icon-theme='Enclave'" "Wayland GTK icons = Enclave Icons"
has "$AIR/usr/share/glib-2.0/schemas/90_enclave.gschema.override" "cursor-theme='Enclave-cursors'" "cursor = Enclave"
has "$AIR/usr/share/glib-2.0/schemas/90_enclave.gschema.override" "font-name='Inter" "UI font = Inter"
has "$PKG" '^inter-font$'                                   "pkg: inter-font"
ICONS="arch/icons/Enclave"
has "$ICONS/index.theme" '^Inherits=hicolor,Papirus,'       "third-party apps keep their own icons; Papirus fills gaps"
has "arch/icons/Enclave-dark/index.theme" '^Inherits=hicolor,Papirus-Dark,' "dark variant: same, on Papirus-Dark"
for n in zen zen-browser thunderbird org.mozilla.Thunderbird wine foot; do
  gone "$ICONS/scalable/apps/$n.svg"                        "third-party app keeps its own icon: $n"
done
has "$PKG" '^papirus-icon-theme$'                           "pkg: Papirus (base for Enclave Icons)"
has "scripts/build-iso.sh" 'ln -s \.\./Enclave/scalable'    "Enclave-dark shares Enclave's icons"
lacks "scripts/build-iso.sh" 'WhiteSur'                     "no WhiteSur fetch/installer in the build"
exists "tools/make-icons.py"                                "Enclave Icons are reproducible"
for i in apps/enclave apps/start-here apps/enclave-assistant apps/enclave-install apps/system-file-manager          apps/utilities-terminal apps/accessories-text-editor apps/image-viewer apps/multimedia-video-player          apps/preferences-system apps/applets-screenshooter apps/utilities-system-monitor          places/folder places/user-home places/folder-documents places/folder-download          places/user-trash places/user-trash-full devices/drive-harddisk mimetypes/inode-directory; do
  exists "$ICONS/scalable/$i.svg"                           "Enclave icon: $i"
done
# Qt's SVG renderer (the shell) ignores these; icons must not rely on them.
if grep -lE '<filter|<mask|clipPath|<image' "$ICONS"/scalable/*/*.svg >/dev/null 2>&1; then
  bad "Enclave icons avoid filters/masks/clip paths"
else
  pass "Enclave icons avoid filters/masks/clip paths"
fi
# Every launcher Enclave ships has an Enclave icon.
for f in "$AIR"/usr/share/applications/*.desktop "$AIR"/usr/local/share/applications/*.desktop          desktop/session/rootfs/usr/share/applications/*.desktop desktop/terminal/*.desktop; do
  n=$(sed -n 's/^Icon=//p' "$f" | head -1)
  [ -n "$n" ] || continue
  exists "$ICONS/scalable/apps/$n.svg"                      "$(basename "$f") has an Enclave icon ($n)"
done
has "desktop/session/rootfs/usr/bin/enclave-session" '^export QT_QPA_PLATFORMTHEME=gtk3' "Qt apps follow the GTK icon theme"
has "desktop/session/rootfs/usr/bin/enclave-shell-run" 'env -u QT_QPA_PLATFORMTHEME enclave-shell' "the shell styles itself"
has "$AIR/usr/share/applications/enclave-assistant.desktop" '^Icon=enclave-assistant$' "Assistant uses its themed icon"
has "$AIR/usr/share/applications/enclave-install.desktop" '^Icon=enclave-install$' "Installer uses its themed icon"
has "scripts/build-iso.sh" 'FLUENT_GTK_REV="[0-9a-f]{40}"'  "GTK theme source is pinned"
has "$AIR/usr/share/enclave/menus/enclave-applications.menu" 'enclave-settings\.desktop' "one Settings entry"
has "$AIR/usr/local/share/applications/org.xfce.ristretto.desktop" '^Name=Photos$' "image viewer branded 'Photos'"
has "$AIR/usr/local/share/applications/io.github.celluloid_player.Celluloid.desktop" '^Name=Media Player$' "video player branded 'Media Player'"
has "$AIR/usr/local/share/applications/thunar.desktop" '^Name=Files' "file manager branded 'Files'"

# --- wallpapers: Ember Horizon, light and dark ---
for w in enclave-default enclave-default-light enclave-login; do
  exists "arch/branding/wallpapers/$w.svg"                  "wallpaper: $w"
done
exists "tools/make-wallpapers.py"                           "wallpapers are reproducible"

# --- default apps ---
has "$PKG" '^zen-browser-bin$'                              "pkg: Zen Browser"
has "scripts/build-iso.sh" 'AUR_PKGS=[(].*zen-browser-bin'  "Zen Browser built from the AUR"
has "$PKG" '^thunderbird$'                                  "pkg: Thunderbird"
has "$AIR/etc/xdg/mimeapps.list" '^x-scheme-handler/https=zen\.desktop' "Zen is the default browser"
has "$AIR/etc/xdg/mimeapps.list" '^x-scheme-handler/mailto=org\.mozilla\.Thunderbird\.desktop' "Thunderbird is the default mail app"

# --- boot: Ember Plymouth splash, quiet kernel, quick menus ---
exists "arch/plymouth/enclave/enclave.script"               "Plymouth Enclave script theme"
has "arch/plymouth/enclave/enclave.plymouth" '^ModuleName=script$' "Plymouth theme is a script theme"
has "arch/plymouth/enclave/enclave.script" 'SetDisplayPasswordFunction' "splash asks for disk passphrases"
has "$AIR/etc/plymouth/plymouthd.conf" '^Theme=enclave$'    "Plymouth uses the Enclave theme"
has "arch/boot/grub/grub.cfg" 'quiet splash loglevel=3'    "live boot is quiet"
has "$AIR/etc/calamares/modules/grubcfg.conf" 'GRUB_TIMEOUT_STYLE: "hidden"' "installed boot hides the GRUB menu"
has "$AIR/etc/calamares/modules/grubcfg.conf" '"splash"'    "installed boot shows the splash"
# --- boot menu: UEFI only, one Enclave entry, Enclave's GRUB theme ---
has "scripts/build-iso.sh" "bootmodes=\('uefi\.grub'\)"   "ISO boots UEFI only (GRUB)"
has "scripts/build-iso.sh" 'rm -rf "\$PROFILE/syslinux"'    "build drops the BIOS (syslinux) menu"
has "arch/overlay/packages.remove" '^syslinux$'             "syslinux not shipped"
has "arch/overlay/packages.remove" '^memtest86\+'           "memtest not shipped"
if [ "$(grep -c '^menuentry' arch/boot/grub/grub.cfg)" = 1 ]; then
  pass "live boot menu has exactly one entry"
else
  bad "live boot menu has exactly one entry ($(grep -c '^menuentry' arch/boot/grub/grub.cfg))"
fi
has "arch/boot/grub/grub.cfg" '^menuentry "Start Enclave OS"' "the entry is Start Enclave OS"
lacks "arch/boot/grub/grub.cfg" '[Ss]peech|accessibility|memtest|[Aa]rch Linux' "no speech/memtest/Arch entries"
lacks "arch/boot/grub/loopback.cfg" '[Ss]peech|accessibility|memtest|[Aa]rch Linux' "loopback menu: no extra entries"
has "arch/boot/grub/grub.cfg" 'theme=.*enclave_theme|set theme='  "live menu uses the Enclave GRUB theme"
has "arch/boot/grub/theme.txt" '__timeout__'                "menu countdown is a text label"
lacks "arch/boot/grub/theme.txt" 'progress_bar'             "no GRUB progress bar"
has "arch/boot/art/background.svg" '101114'                 "boot background in Obsidian/Ember"
has "tools/make-boot-art.sh" 'INSTALLED'                    "art script also renders the installed system's theme"
has "$AIR/etc/calamares/modules/grubcfg.conf" 'GRUB_THEME: "/usr/share/grub/themes/enclave/theme.txt"' "installed GRUB uses the Enclave theme"
if bash -n tools/make-boot-art.sh; then pass "make-boot-art.sh parses"; else bad "make-boot-art.sh parse"; fi

# --- executables really are executable in the image (mkarchiso drops file
#     modes; only profiledef file_permissions survive — alpha.10 shipped 0644) ---
has "scripts/build-iso.sh" 'file_permissions\+='           "build registers Enclave executables in file_permissions"
if find "$AIR/usr/local/bin" -name '__pycache__' 2>/dev/null | grep -q .; then
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

# --- SDDM login theme (runs under X11; the session itself is Wayland) ---
SDDM="$AIR/usr/share/sddm/themes/enclave"
has "$SDDM/metadata.desktop" 'Type=sddm-theme'              "sddm theme metadata"
has "$SDDM/metadata.desktop" '^MainScript=Main.qml'         "sddm theme main script"
exists "$SDDM/Main.qml"                                      "sddm theme Main.qml present"
has "$SDDM/Main.qml" 'sddm\.login'                          "sddm theme performs login"
has "$AIR/etc/sddm.conf.d/05-enclave-theme.conf" '^Current=enclave' "sddm uses the Enclave theme"
exists "arch/branding/wallpapers/enclave-login.svg"         "login background present"

exit $fail
