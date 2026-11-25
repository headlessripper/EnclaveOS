#!/usr/bin/env bash
#
# Enclave OS — build the branded Arch live/install ISO.
#
# Assembles a profile from the system `releng` archiso profile plus Enclave's
# overlay (arch/overlay + arch/profiledef.overrides + arch/branding), then runs
# mkarchiso. Must run on Arch Linux as root (mkarchiso needs root + loop devices).
#
# Usage:
#   sudo scripts/build-iso.sh [--output DIR] [--keep-work]
#
set -euo pipefail

# --- locate repo ---
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ARCH_DIR="$REPO/arch"
OVERLAY="$ARCH_DIR/overlay"
BRANDING="$ARCH_DIR/branding"
RELENG="/usr/share/archiso/configs/releng"

OUT="$REPO/dist"
# WORK/PROFILE can be redirected off the repo (e.g. onto the container's native
# filesystem) via ENCLAVE_WORK — archiso loop-mounts its airootfs image, which
# fails on a Windows/9p bind mount. Default keeps everything under the repo.
WORK="${ENCLAVE_WORK:-$REPO/build}/work"
PROFILE="${ENCLAVE_WORK:-$REPO/build}/profile"
KEEP_WORK=0

# --- args ---
while [ $# -gt 0 ]; do
  case "$1" in
    --output) OUT="$2"; shift 2 ;;
    --keep-work) KEEP_WORK=1; shift ;;
    -h|--help)
      sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

log() { printf '\033[38;2;255;122;61m[enclave]\033[0m %s\n' "$*"; }
die() { printf '\033[31m[enclave] error:\033[0m %s\n' "$*" >&2; exit 1; }

# --- preflight ---
[ "$(id -u)" -eq 0 ] || die "must run as root (mkarchiso needs root). Try: sudo $0"
command -v mkarchiso >/dev/null 2>&1 || die "mkarchiso not found. Install it: pacman -S archiso"
[ -d "$RELENG" ] || die "releng profile not found at $RELENG (reinstall archiso)"
[ -d "$OVERLAY" ] || die "overlay not found at $OVERLAY"

# Reproducible-ish: pin the build date to the last commit when git is available.
if command -v git >/dev/null 2>&1 && git -C "$REPO" rev-parse >/dev/null 2>&1; then
  export SOURCE_DATE_EPOCH="$(git -C "$REPO" log -1 --format=%ct)"
fi

# --- 1. seed the profile from releng ---
log "seeding profile from $RELENG"
rm -rf "$PROFILE"
mkdir -p "$PROFILE"
cp -aT "$RELENG" "$PROFILE"

# --- 2. apply Enclave identity to profiledef.sh ---
set_profiledef() { # key value file
  awk -v k="$1" -v v="$2" '
    $0 ~ "^"k"=" { print k"=\""v"\""; next } { print }
  ' "$3" > "$3.tmp" && mv "$3.tmp" "$3"
}
if [ -f "$ARCH_DIR/profiledef.overrides" ]; then
  log "applying identity overrides"
  while IFS='=' read -r key val; do
    [ -z "$key" ] && continue
    case "$key" in \#*) continue ;; esac
    if [ "$key" = "iso_label" ]; then
      val="${val}_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
    fi
    set_profiledef "$key" "$val" "$PROFILE/profiledef.sh"
  done < "$ARCH_DIR/profiledef.overrides"
fi

# --- 3. pacman.conf (adds [multilib]) ---
[ -f "$OVERLAY/pacman.conf" ] && cp -f "$OVERLAY/pacman.conf" "$PROFILE/pacman.conf"

# --- 4. extra packages ---
if [ -f "$OVERLAY/packages.x86_64.extra" ]; then
  log "appending Enclave packages"
  {
    echo ""
    echo "# --- Enclave additions ---"
    grep -vE '^\s*(#|$)' "$OVERLAY/packages.x86_64.extra"
  } >> "$PROFILE/packages.x86_64"
fi

# --- 4b. debloat: strip niche releng live-ISO packages ---
if [ -f "$OVERLAY/packages.remove" ]; then
  log "removing bloat packages"
  rmf="$(mktemp)"
  grep -vE '^\s*(#|$)' "$OVERLAY/packages.remove" > "$rmf"
  before="$(grep -cvE '^\s*(#|$)' "$PROFILE/packages.x86_64")"
  grep -vxFf "$rmf" "$PROFILE/packages.x86_64" > "$PROFILE/packages.x86_64.new"
  mv "$PROFILE/packages.x86_64.new" "$PROFILE/packages.x86_64"
  after="$(grep -cvE '^\s*(#|$)' "$PROFILE/packages.x86_64")"
  rm -f "$rmf"
  log "  packages: $before -> $after"
fi

# --- 5. overlay airootfs ---
log "overlaying airootfs"
cp -aT "$OVERLAY/airootfs" "$PROFILE/airootfs"
AIR="$PROFILE/airootfs"
# Python bytecode caches never belong in the image.
find "$AIR" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true

# --- 5b. file modes ---
# mkarchiso copies airootfs with `cp --no-preserve=mode` and then applies ONLY
# profiledef.sh's file_permissions, so chmod here would be silently discarded
# (alpha.10 shipped every Enclave script as 0644). Register each executable.
add_file_perm() { # path-in-image mode
  printf 'file_permissions+=(["%s"]="0:0:%s")\n' "$1" "$2" >> "$PROFILE/profiledef.sh"
}
{ echo ""; echo "# --- Enclave executables (added by build-iso.sh) ---"; } >> "$PROFILE/profiledef.sh"
for f in "$AIR"/usr/local/bin/*; do
  [ -f "$f" ] && add_file_perm "/usr/local/bin/$(basename "$f")" 755
done
for f in "$AIR"/etc/grub.d/*; do
  [ -f "$f" ] && add_file_perm "/etc/grub.d/$(basename "$f")" 755
done
for f in "$AIR"/etc/skel/Desktop/*.desktop; do
  [ -f "$f" ] && add_file_perm "/etc/skel/Desktop/$(basename "$f")" 755
done

# --- 5c. live ISO: drop releng services a desktop live session doesn't want ---
# sshd (releng enables root password login), cloud-init, and networkd's
# wait-online (NetworkManager owns networking; wait-online only stalls boot).
rm -f "$AIR/etc/systemd/system/multi-user.target.wants/sshd.service" \
      "$AIR/etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service"
rm -rf "$AIR/etc/systemd/system/cloud-init.target.wants"

# --- 6. branding assets into the image ---
if [ -d "$BRANDING" ]; then
  install -d "$AIR/usr/share/enclave"
  cp -a "$BRANDING/." "$AIR/usr/share/enclave/"
fi
# Calamares branding expects its images beside branding.desc; stamp the
# installer's version with the image date.
CALB="$AIR/etc/calamares/branding/enclave"
if [ -d "$CALB" ]; then
  cp -f "$BRANDING/enclave-logo.svg" "$BRANDING/enclave-logo-dark.svg" "$CALB/"
  stamp="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
  sed -i -E "s/^(  (version|shortVersion):[[:space:]]+).*/\1$stamp/" "$CALB/branding.desc"
fi
# --- 6b. desktop look: GTK/window theme, icons and cursor (Fluent, the
#         Windows-11 design language), recoloured to Enclave orange and
#         installed under Enclave names. These are the desktop's look, so a
#         build without them fails loudly instead of shipping a stock look.
#         Sources are pinned so a rebuild can't silently change the look.
FLUENT_GTK_REV="7a49a464b0188c340101c52965c18190b1c694cf"   # Fluent-gtk-theme HEAD, 2026-11
FLUENT_ICON_REV="c70c2441bcf2ab8bbc267e55635c76d69f659a8b"  # Fluent-icon-theme tag 2026-07-27 (cursors)
command -v git   >/dev/null 2>&1 || die "git not found (needed for the Enclave theme)"
command -v sassc >/dev/null 2>&1 || die "sassc not found (needed to build the Enclave theme): pacman -S sassc"
THEMETMP="$(mktemp -d)"
fetch_rev() { # url rev dest — shallow fetch of one pinned commit, with retries
  local i
  for i in 1 2 3 4 5; do
    rm -rf "$3"; mkdir -p "$3"
    if git -C "$3" init -q && git -C "$3" fetch -q --depth 1 "$1" "$2" \
       && git -C "$3" -c advice.detachedHead=false checkout -q FETCH_HEAD; then
      return 0
    fi
    sleep 3
  done
  return 1
}
run_logged() { # logfile cmd... — keep installer chatter out of the log unless it fails
  local lf="$1"; shift
  if ! "$@" >"$lf" 2>&1 </dev/null; then
    tail -n 30 "$lf" >&2; return 1
  fi
}

log "building Enclave GTK + window theme (Fluent @ ${FLUENT_GTK_REV:0:7})"
fetch_rev https://github.com/vinceliuice/Fluent-gtk-theme.git "$FLUENT_GTK_REV" "$THEMETMP/gtk" \
  || die "could not fetch Fluent-gtk-theme"
# Ember colours and the rounded-everything rule go into Fluent's source
# before it is built (tools/enclave-gtk-patch.sh), in light and dark:
#   Enclave       — light (Porcelain, Burnt Orange accent)
#   Enclave-Dark  — dark  (Obsidian/Graphite, Ember accent) — the default
# then the Enclave layer (arch/themes/gtk/enclave-layer.css: rounded buttons
# everywhere, Files restyle) is appended to every GTK 3 / 4 stylesheet.
bash "$REPO/tools/enclave-gtk-patch.sh" "$THEMETMP/gtk" || die "Enclave GTK patch failed"
install -d "$AIR/usr/share/themes"
( cd "$THEMETMP/gtk" && run_logged "$THEMETMP/gtk.log" ./install.sh -t orange -c light dark --tweaks round -d "$AIR/usr/share/themes" ) \
  || die "Fluent-gtk-theme install failed"
for v in Light Dark; do
  [ -d "$AIR/usr/share/themes/Fluent-round-orange-$v" ] || die "Fluent $v theme folder missing after install"
done
rm -rf "$AIR/usr/share/themes/Enclave" "$AIR/usr/share/themes/Enclave-Dark" "$AIR"/usr/share/themes/Fluent-round-orange-*-compact
mv "$AIR/usr/share/themes/Fluent-round-orange-Light" "$AIR/usr/share/themes/Enclave"
mv "$AIR/usr/share/themes/Fluent-round-orange-Dark" "$AIR/usr/share/themes/Enclave-Dark"
for t in Enclave Enclave-Dark; do
  sed -i "s/^Name=.*/Name=$t/; s/^GtkTheme=.*/GtkTheme=$t/; s/^MetacityTheme=.*/MetacityTheme=$t/;
          s/^IconTheme=.*/IconTheme=Enclave/; s/^CursorTheme=.*/CursorTheme=Enclave-cursors/" \
    "$AIR/usr/share/themes/$t/index.theme"
  for css in "$AIR/usr/share/themes/$t"/gtk-3.0/gtk*.css "$AIR/usr/share/themes/$t"/gtk-4.0/gtk*.css; do
    [ -f "$css" ] || continue
    printf '\n' >> "$css"; cat "$REPO/arch/themes/gtk/enclave-layer.css" >> "$css"
  done
  grep -qs 'Enclave layer' "$AIR/usr/share/themes/$t/gtk-3.0/gtk.css" || die "Enclave layer missing from $t"
done
# Window frames: show the app icon at the top-left like Windows (Fluent hides it).
log "  Enclave theme installed"

# Enclave Icons: Enclave's own set (arch/icons/Enclave, drawn by
# tools/make-icons.py: apps, folders, places, drives, trash) layered on
# Papirus (packages.x86_64.extra) for the thousands of other app, file-type
# and symbolic icons. Enclave-dark shares the same icons and inherits
# Papirus-Dark, so symbolic icons stay legible in dark mode.
log "installing Enclave Icons + cursor (Fluent @ ${FLUENT_ICON_REV:0:7})"
install -d "$AIR/usr/share/icons"
[ -f "$REPO/arch/icons/Enclave/scalable/apps/enclave.svg" ] || die "Enclave Icons missing (run tools/make-icons.py)"
rm -rf "$AIR/usr/share/icons/Enclave" "$AIR/usr/share/icons/Enclave-light" "$AIR/usr/share/icons/Enclave-dark"
cp -a "$REPO/arch/icons/Enclave" "$AIR/usr/share/icons/Enclave"
install -d "$AIR/usr/share/icons/Enclave-dark"
cp -f "$REPO/arch/icons/Enclave-dark/index.theme" "$AIR/usr/share/icons/Enclave-dark/index.theme"
ln -s ../Enclave/scalable "$AIR/usr/share/icons/Enclave-dark/scalable"
# Cursors stay Enclave's (from Fluent).
fetch_rev https://github.com/vinceliuice/Fluent-icon-theme.git "$FLUENT_ICON_REV" "$THEMETMP/icons"   || die "could not fetch Fluent-icon-theme (cursors)"
rm -rf "$AIR/usr/share/icons/Enclave-cursors"
cp -a "$THEMETMP/icons/cursors/dist" "$AIR/usr/share/icons/Enclave-cursors"
printf '[Icon Theme]
Name=Enclave Cursors
Comment=Enclave pointer theme
' > "$AIR/usr/share/icons/Enclave-cursors/index.theme"
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  for t in "$AIR"/usr/share/icons/Enclave "$AIR"/usr/share/icons/Enclave-dark; do
    [ -d "$t" ] && gtk-update-icon-cache -q -f -t "$t" 2>/dev/null || true
  done
fi
rm -rf "$THEMETMP"
log "  Enclave icons + cursor installed"

# --- 6b3. Enclave Shell (Enclave's own Wayland desktop, Qt 6 / QML) and its
#          Hyprland session ("Enclave" on the login screen).
#          Compiled against the same Arch Qt the image installs. ---
DESKTOP_DIR="$REPO/desktop"
if [ -d "$DESKTOP_DIR/shell" ]; then
  command -v cmake >/dev/null 2>&1 || die "cmake not found (pacman -S cmake) — needed for Enclave Shell"
  [ -f /usr/share/wlr-protocols/unstable/wlr-foreign-toplevel-management-unstable-v1.xml ] \
    || die "wlr-protocols not found (pacman -S wlr-protocols) — needed for Enclave Shell"
  log "compiling Enclave Shell"
  SHELLBUILD="${ENCLAVE_WORK:-$REPO/build}/enclave-shell"
  rm -rf "$SHELLBUILD" "$SHELLBUILD.log"
  run_logged "$SHELLBUILD.log" cmake -S "$DESKTOP_DIR/shell" -B "$SHELLBUILD" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr || die "Enclave Shell: cmake configure failed"
  run_logged "$SHELLBUILD.log" cmake --build "$SHELLBUILD" -j"$(nproc)" || die "Enclave Shell failed to compile"
  run_logged "$SHELLBUILD.log" env DESTDIR="$AIR" cmake --install "$SHELLBUILD" || die "Enclave Shell failed to install"
  [ -x "$AIR/usr/bin/enclave-shell" ] || die "Enclave Shell did not install"
  cp -a "$DESKTOP_DIR/session/rootfs/." "$AIR/"
  # Hyprland only on the ISO: labwc's config is for the screenshot rig.
  rm -rf "$AIR/usr/share/enclave/labwc" "$AIR/usr/share/themes/Enclave-Ember/labwc"
  # Stamp the image version, and keep Enclave's identity where package
  # updates can't replace it (Settings > About reads this copy first).
  if [ -f "$AIR/etc/os-release" ]; then
    stamp="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
    sed -i '/^IMAGE_VERSION=/d' "$AIR/etc/os-release"
    echo "IMAGE_VERSION=$stamp" >> "$AIR/etc/os-release"
    install -Dm644 "$AIR/etc/os-release" "$AIR/usr/share/enclave/os-release"
  fi
  install -Dm644 "$DESKTOP_DIR/design-system/tokens/ember.json" \
    "$AIR/usr/share/enclave/design-system/ember.json"
  for f in enclave-shell enclave-session enclave-shell-run enclave-screenshot enclave-settings enclave-files; do
    add_file_perm "/usr/bin/$f" 755
  done
  log "  Enclave Shell + Wayland session installed"
fi

# --- 6b4. Enclave Terminal (QTermWidget in an Ember window; the default
#          terminal for the dock, Super+Return, Files and terminal apps). ---
if [ -d "$DESKTOP_DIR/terminal" ]; then
  [ -f /usr/lib/cmake/qtermwidget6/qtermwidget6-config.cmake ] \
    || die "qtermwidget not found (pacman -S qtermwidget) — needed for Enclave Terminal"
  log "compiling Enclave Terminal"
  TERMBUILD="${ENCLAVE_WORK:-$REPO/build}/enclave-terminal"
  rm -rf "$TERMBUILD" "$TERMBUILD.log"
  run_logged "$TERMBUILD.log" cmake -S "$DESKTOP_DIR/terminal" -B "$TERMBUILD" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr || die "Enclave Terminal: cmake configure failed"
  run_logged "$TERMBUILD.log" cmake --build "$TERMBUILD" -j"$(nproc)" || die "Enclave Terminal failed to compile"
  run_logged "$TERMBUILD.log" env DESTDIR="$AIR" cmake --install "$TERMBUILD" || die "Enclave Terminal failed to install"
  [ -x "$AIR/usr/bin/enclave-terminal" ] || die "Enclave Terminal did not install"
  add_file_perm "/usr/bin/enclave-terminal" 755
  log "  Enclave Terminal installed"
fi

# --- 6c. Boot look: Enclave's own UEFI boot menu and Plymouth splash ---
#     Enclave boots UEFI only (no BIOS/syslinux, no systemd-boot text menu):
#     GRUB shows one "Start Enclave OS" entry in Enclave's theme, then the
#     Plymouth splash takes over on the same background, mark and wordmark.
#     tools/make-boot-art.sh renders both from arch/boot/art + the brand SVGs.
log "boot look: themed UEFI boot menu + Enclave splash"
command -v grub-mkfont >/dev/null 2>&1 || die "grub not found (pacman -S grub) — needed for the boot menu"
command -v rsvg-convert >/dev/null 2>&1 || die "rsvg-convert not found (pacman -S librsvg) — needed for the boot art"
# One bootloader, UEFI: replace releng's bootmodes array.
awk '
  /^bootmodes=\(/ { print "bootmodes=('"'"'uefi.grub'"'"')"; skip = ($0 !~ /\)/); next }
  skip { if ($0 ~ /\)/) skip = 0; next }
  { print }
' "$PROFILE/profiledef.sh" > "$PROFILE/profiledef.sh.tmp" && mv "$PROFILE/profiledef.sh.tmp" "$PROFILE/profiledef.sh"
grep -q "^bootmodes=('uefi.grub')$" "$PROFILE/profiledef.sh" || die "could not set the UEFI boot mode"
rm -rf "$PROFILE/syslinux" "$PROFILE/efiboot" "$PROFILE/grub"
install -d "$PROFILE/grub"
cp "$REPO/arch/boot/grub/grub.cfg" "$REPO/arch/boot/grub/loopback.cfg" "$PROFILE/grub/"
PTH="$AIR/usr/share/plymouth/themes/enclave"
rm -rf "$PTH"; install -d "$PTH"
bash "$REPO/tools/make-boot-art.sh" "$PROFILE/grub/themes/enclave" "$PTH" \
  "Live · $(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)" \
  "$AIR/usr/share/grub/themes/enclave" || die "boot art failed"
# (the last directory is the installed system's GRUB theme: wider menu for its
#  three entries, no "Live" label; Calamares' grubcfg.conf points GRUB at it)
cp "$REPO/arch/plymouth/enclave/enclave.plymouth" "$REPO/arch/plymouth/enclave/enclave.script" "$PTH/"
# Live ISO initramfs: add the plymouth hook (right after udev) so the splash
# shows on the live boot too.
for mk in "$AIR"/etc/mkinitcpio.conf.d/*.conf; do
  [ -f "$mk" ] || continue
  grep -q 'plymouth' "$mk" 2>/dev/null && continue
  sed -i 's/\(HOOKS=([^)]*\budev\b\)/\1 plymouth/' "$mk" 2>/dev/null || true
done
grep -qs 'plymouth' "$AIR/etc/mkinitcpio.conf.d/archiso.conf" || die "plymouth hook missing from the live initramfs"

# --- 7. service wiring (symlinks created here so the repo stays Windows-clean) ---
log "wiring services (graphical default, SDDM, NetworkManager, live setup)"
ln -sfn /usr/lib/systemd/system/graphical.target "$AIR/etc/systemd/system/default.target"
ln -sfn /usr/lib/systemd/system/sddm.service     "$AIR/etc/systemd/system/display-manager.service"
install -d "$AIR/etc/systemd/system/multi-user.target.wants"
ln -sfn /usr/lib/systemd/system/NetworkManager.service \
  "$AIR/etc/systemd/system/multi-user.target.wants/NetworkManager.service"
ln -sfn ../enclave-live-setup.service \
  "$AIR/etc/systemd/system/multi-user.target.wants/enclave-live-setup.service"
ln -sfn ../enclave-flathub.service \
  "$AIR/etc/systemd/system/multi-user.target.wants/enclave-flathub.service"
# Avoid NetworkManager <-> systemd-networkd/iwd fighting over the live link.
rm -f "$AIR/etc/systemd/system/multi-user.target.wants/systemd-networkd.service" \
      "$AIR/etc/systemd/system/multi-user.target.wants/systemd-networkd-wait-online.service" \
      "$AIR/etc/systemd/system/multi-user.target.wants/iwd.service" \
      "$AIR/etc/systemd/system/sockets.target.wants/systemd-networkd.socket" 2>/dev/null || true

# --- 8b. AUR packages (Calamares, Zen Browser) → a local file:// repo ---
# Neither has an official Arch package. Calamares: no trustworthy prebuilt
# exists (EndeavourOS ships only the PKGBUILD, Chaotic-AUR doesn't carry it), so
# it is compiled here. Zen Browser: the AUR zen-browser-bin package repacks the
# official upstream release tarball. Every dependency of both is in the
# official repos. They reach mkarchiso through a local repo.
AUR_PKGS=(calamares zen-browser-bin)
if command -v makepkg >/dev/null 2>&1; then
  LOCALREPO="${ENCLAVE_WORK:-$REPO/build}/localrepo"
  log "building AUR packages: ${AUR_PKGS[*]} (Calamares compiles, ~10 min)…"
  rm -rf "$LOCALREPO"; install -d "$LOCALREPO"
  # makepkg refuses to run as root; use a throwaway unprivileged builder.
  id builder >/dev/null 2>&1 || useradd -m -s /bin/bash builder
  printf 'builder ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/00-enclave-builder
  chmod 0440 /etc/sudoers.d/00-enclave-builder
  # Robust source download: codeberg.org (the Calamares source host) frequently
  # resets HTTP/2 streams, which aborts makepkg's one-shot download. Give the
  # builder a curl DLAGENT that retries hard and resumes partial transfers.
  # (also: skip the separate -debug split packages; we only ship the main one)
  cat > /home/builder/.makepkg.conf <<'MKCONF'
OPTIONS+=(!debug)
DLAGENTS=('https::/usr/bin/curl -qgb "" -fLC - --retry 20 --retry-delay 3 --retry-all-errors --connect-timeout 30 -o %o %u'
          'http::/usr/bin/curl -qgb "" -fLC - --retry 20 --retry-delay 3 --retry-all-errors --connect-timeout 30 -o %o %u')
MKCONF
  chown builder:builder /home/builder/.makepkg.conf
  BUILDTMP="$(sudo -u builder mktemp -d)"
  for pkg in "${AUR_PKGS[@]}"; do
    log "  makepkg $pkg"
    sudo -u builder env MAKEFLAGS="-j$(nproc)" bash -euc "
      cd '$BUILDTMP'
      for i in 1 2 3 4 5; do
        git clone -q --depth 1 https://aur.archlinux.org/$pkg.git && break
        rm -rf $pkg; sleep 3
      done
      cd $pkg
      makepkg -s --noconfirm --needed
    "
    # Main package only (the glob also matches a -debug split package if one
    # was produced; skip it).
    found=0
    for p in "$BUILDTMP/$pkg/$pkg"-[0-9]*.pkg.tar.*; do
      case "$p" in *-debug-*|*.sig) continue ;; esac
      [ -f "$p" ] && cp "$p" "$LOCALREPO"/ && found=1
    done
    [ "$found" -eq 1 ] || die "AUR package $pkg did not build"
  done
  repo-add -q "$LOCALREPO/enclave-local.db.tar.gz" "$LOCALREPO"/*.pkg.tar.*
  rm -rf "$BUILDTMP"
  cat >> "$PROFILE/pacman.conf" <<EOF

[enclave-local]
SigLevel = Never
Server = file://$LOCALREPO
EOF
  log "  AUR packages staged in local repo"
else
  die "makepkg not found — needed to build the AUR packages (install base-devel)"
fi

# --- 9. build ---
mkdir -p "$OUT"
log "running mkarchiso (this takes a while and downloads packages)…"
mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE"

[ "$KEEP_WORK" -eq 1 ] || rm -rf "$WORK"
log "done. ISO(s) in: $OUT"
ls -1 "$OUT"/*.iso 2>/dev/null || true
