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
# Calamares branding expects its logo beside branding.desc.
if [ -d "$AIR/etc/calamares/branding/enclave" ] && [ -f "$BRANDING/enclave-logo.svg" ]; then
  cp -f "$BRANDING/enclave-logo.svg" "$AIR/etc/calamares/branding/enclave/enclave-logo.svg"
fi
# --- 6b. desktop look: GTK/window theme, icons and cursor (Fluent, the
#         Windows-11 design language), recoloured to Enclave orange and
#         installed under Enclave names. These are the desktop's look, so a
#         build without them fails loudly instead of shipping stock XFCE.
#         Sources are pinned so a rebuild can't silently change the look.
FLUENT_GTK_REV="7a49a464b0188c340101c52965c18190b1c694cf"   # Fluent-gtk-theme HEAD, 2026-11
FLUENT_ICON_REV="c70c2441bcf2ab8bbc267e55635c76d69f659a8b"  # Fluent-icon-theme tag 2026-07-27
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
install -d "$AIR/usr/share/themes"
( cd "$THEMETMP/gtk" && run_logged "$THEMETMP/gtk.log" ./install.sh -t orange -c light --tweaks round -d "$AIR/usr/share/themes" ) \
  || die "Fluent-gtk-theme install failed"
[ -d "$AIR/usr/share/themes/Fluent-round-orange-Light" ] || die "Fluent theme folder missing after install"
rm -rf "$AIR/usr/share/themes/Enclave" "$AIR"/usr/share/themes/Fluent-round-orange-Light-*
mv "$AIR/usr/share/themes/Fluent-round-orange-Light" "$AIR/usr/share/themes/Enclave"
sed -i 's/^Name=.*/Name=Enclave/; s/^GtkTheme=.*/GtkTheme=Enclave/; s/^MetacityTheme=.*/MetacityTheme=Enclave/;
        s/^IconTheme=.*/IconTheme=Enclave-orange-light/; s/^CursorTheme=.*/CursorTheme=Enclave-cursors/' \
  "$AIR/usr/share/themes/Enclave/index.theme"
# Window frames: show the app icon at the top-left like Windows (Fluent hides it).
XFWM_RC="$AIR/usr/share/themes/Enclave/xfwm4/themerc"
[ -f "$XFWM_RC" ] || die "Enclave theme has no xfwm4 frames"
if grep -q '^show_app_icon=' "$XFWM_RC"; then
  sed -i 's/^show_app_icon=.*/show_app_icon=true/' "$XFWM_RC"
else
  echo 'show_app_icon=true' >> "$XFWM_RC"
fi
log "  Enclave theme installed"

log "building Enclave icons + cursor (Fluent icons @ ${FLUENT_ICON_REV:0:7})"
fetch_rev https://github.com/vinceliuice/Fluent-icon-theme.git "$FLUENT_ICON_REV" "$THEMETMP/icons" \
  || die "could not fetch Fluent-icon-theme"
install -d "$AIR/usr/share/icons"
( cd "$THEMETMP/icons" && run_logged "$THEMETMP/icons.log" ./install.sh -d "$AIR/usr/share/icons" -n Enclave orange ) \
  || die "Fluent-icon-theme install failed"
[ -f "$AIR/usr/share/icons/Enclave-orange-light/index.theme" ] || die "Enclave-orange-light icons missing after install"
rm -rf "$AIR/usr/share/icons/Enclave-cursors"
cp -a "$THEMETMP/icons/cursors/dist" "$AIR/usr/share/icons/Enclave-cursors"
printf '[Icon Theme]\nName=Enclave Cursors\nComment=Enclave pointer theme\n' > "$AIR/usr/share/icons/Enclave-cursors/index.theme"
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  for t in "$AIR"/usr/share/icons/Enclave-orange*; do
    [ -d "$t" ] && gtk-update-icon-cache -q -f -t "$t" 2>/dev/null || true
  done
fi
rm -rf "$THEMETMP"
log "  Enclave icons + cursor installed"

# --- 6c. Plymouth boot splash: skin the boot logs with an Enclave theme.
#     Built by recolouring the bundled "spinner" theme (reliable, known-good). ---
if [ -d /usr/share/plymouth/themes/spinner ]; then
  log "building Enclave Plymouth boot splash"
  PTH="$AIR/usr/share/plymouth/themes/enclave"
  rm -rf "$PTH"; install -d "$PTH"
  cp -a /usr/share/plymouth/themes/spinner/. "$PTH/"
  mv -f "$PTH/spinner.plymouth" "$PTH/enclave.plymouth" 2>/dev/null || true
  sed -i 's/^Name=.*/Name=Enclave/; s/^Description=.*/Description=Enclave boot splash/' "$PTH/enclave.plymouth" 2>/dev/null || true
  # Enclave dark background.
  if grep -q 'BackgroundStartColor' "$PTH/enclave.plymouth" 2>/dev/null; then
    sed -i 's/^BackgroundStartColor=.*/BackgroundStartColor=0x0b1220/; s/^BackgroundEndColor=.*/BackgroundEndColor=0x0a1018/' "$PTH/enclave.plymouth"
  else
    printf '\nBackgroundStartColor=0x0b1220\nBackgroundEndColor=0x0a1018\n' >> "$PTH/enclave.plymouth"
  fi
  # Enclave logo as the watermark.
  if command -v rsvg-convert >/dev/null 2>&1 && [ -f "$BRANDING/enclave-logo-dark.svg" ]; then
    rsvg-convert -w 160 -h 160 "$BRANDING/enclave-logo-dark.svg" -o "$PTH/watermark.png" 2>/dev/null || true
  fi
  # Live ISO initramfs: add the plymouth hook (right after udev) so the splash
  # shows on the live boot too.
  for mk in "$AIR"/etc/mkinitcpio.conf.d/*.conf "$PROFILE"/airootfs/etc/mkinitcpio.conf.d/*.conf; do
    [ -f "$mk" ] || continue
    grep -q 'plymouth' "$mk" 2>/dev/null && continue
    sed -i 's/\(HOOKS=([^)]*\budev\b\)/\1 plymouth/' "$mk" 2>/dev/null || true
  done
  # Quiet the kernel log and enable the splash on every boot entry.
  grep -rIl --null 'archisobasedir\|APPEND\|linux /' \
    "$PROFILE/syslinux" "$PROFILE/grub" "$PROFILE/efiboot" 2>/dev/null \
    | xargs -0 -r sed -i -E 's/(archisobasedir=[^ ]+)/\1 quiet splash/' 2>/dev/null || true
fi

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

# --- 8. human-readable boot menu titles ---
# NOTE: these grep|xargs pipelines use `|| true` because under `set -o pipefail`
# a grep that matches nothing returns non-zero and would abort the build.
log "branding boot menus"
{ grep -rIl --null 'Arch Linux' \
  "$PROFILE/syslinux" "$PROFILE/grub" "$PROFILE/efiboot" 2>/dev/null \
  | xargs -0 -r sed -i 's/Arch Linux install medium/Enclave OS/g; s/Arch Linux/Enclave OS/g'; } || true

# --- 8a. replace the Arch-logo boot splash with Enclave's ---
# BIOS boots syslinux (which shows splash.png). UEFI x64 boots systemd-boot,
# which has no background image, so there is nothing to brand there beyond the
# entry titles above. (GRUB is only used for IA32 UEFI / loopback, and mkarchiso
# does not copy extra files from grub/, so a GRUB background can't be shipped.)
if command -v rsvg-convert >/dev/null 2>&1 && [ -f "$BRANDING/enclave-boot.svg" ] && [ -d "$PROFILE/syslinux" ]; then
  log "branding boot splash (Enclave)"
  rsvg-convert -w 640 -h 480 "$BRANDING/enclave-boot.svg" -o "$PROFILE/syslinux/splash.png" \
    || log "  WARN: could not render the syslinux splash"
fi
# systemd-boot (UEFI): no beep, and a shorter wait before booting Enclave.
LOADER_CONF="$PROFILE/efiboot/loader/loader.conf"
if [ -f "$LOADER_CONF" ]; then
  sed -i '/^beep /d; s/^timeout .*/timeout 5/' "$LOADER_CONF"
fi

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
