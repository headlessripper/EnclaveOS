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
[ -d "$AIR/usr/local/bin" ] && chmod 0755 "$AIR"/usr/local/bin/*

# --- 6. branding assets into the image ---
if [ -d "$BRANDING" ]; then
  install -d "$AIR/usr/share/enclave"
  cp -a "$BRANDING/." "$AIR/usr/share/enclave/"
fi
# Calamares branding expects its logo beside branding.desc.
if [ -d "$AIR/etc/calamares/branding/enclave" ] && [ -f "$BRANDING/enclave-logo.svg" ]; then
  cp -f "$BRANDING/enclave-logo.svg" "$AIR/etc/calamares/branding/enclave/enclave-logo.svg"
fi
# Make sure Enclave scripts are executable in the image (Windows checkouts
# don't carry the exec bit).
if [ -d "$AIR/usr/local/bin" ]; then
  find "$AIR/usr/local/bin" -type f -exec chmod 0755 {} +
fi

# --- 6b. desktop theme: Fluent (Windows-11-like), recolored to Enclave orange,
#         installed as "Enclave" so no third-party/Linux name shows. ---
if command -v git >/dev/null 2>&1 && command -v sassc >/dev/null 2>&1; then
  log "building Enclave desktop theme (Fluent → Enclave, orange)…"
  THEMETMP="$(mktemp -d)"
  ok=0
  for i in 1 2 3 4 5; do
    git clone --depth 1 https://github.com/vinceliuice/Fluent-gtk-theme.git "$THEMETMP/fluent" >/dev/null 2>&1 && { ok=1; break; }
    sleep 3
  done
  if [ "$ok" -eq 1 ]; then
    install -d "$AIR/usr/share/themes"
    ( cd "$THEMETMP/fluent" && ./install.sh -t orange -c light --tweaks round -d "$AIR/usr/share/themes" </dev/null ) >/dev/null 2>&1 || true
    # Rename "Fluent-round-orange-Light" -> "Enclave" (drop the Fluent trace).
    if [ -d "$AIR/usr/share/themes/Fluent-round-orange-Light" ]; then
      rm -rf "$AIR/usr/share/themes/Enclave"
      mv "$AIR/usr/share/themes/Fluent-round-orange-Light" "$AIR/usr/share/themes/Enclave"
      sed -i 's/^Name=.*/Name=Enclave/' "$AIR/usr/share/themes/Enclave/index.theme" 2>/dev/null || true
      log "  Enclave theme installed"
    else
      log "  WARN: Fluent theme folder not found after install"
    fi
    rm -rf "$AIR/usr/share/themes/Fluent-round-orange-Light-compact"
  else
    log "  WARN: could not fetch Fluent theme (network) — desktop falls back to default GTK"
  fi
  rm -rf "$THEMETMP"
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
log "branding boot menus"
grep -rIl --null 'Arch Linux' \
  "$PROFILE/syslinux" "$PROFILE/grub" "$PROFILE/efiboot" 2>/dev/null \
  | xargs -0 -r sed -i 's/Arch Linux/Enclave OS/g'

# --- 8b. Calamares installer: build from AUR into a local file:// repo ---
# No trustworthy prebuilt Calamares exists for Arch (EndeavourOS ships only the
# PKGBUILD, Chaotic-AUR doesn't carry it). Every Calamares dependency is in the
# official repos, so we compile just Calamares here and hand it to mkarchiso via
# a local repo. Skipped automatically if makepkg isn't available.
if command -v makepkg >/dev/null 2>&1; then
  LOCALREPO="${ENCLAVE_WORK:-$REPO/build}/localrepo"
  log "building Calamares from AUR (one-time compile, ~10 min)…"
  rm -rf "$LOCALREPO"; install -d "$LOCALREPO"
  # makepkg refuses to run as root; use a throwaway unprivileged builder.
  id builder >/dev/null 2>&1 || useradd -m -s /bin/bash builder
  printf 'builder ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/00-enclave-builder
  chmod 0440 /etc/sudoers.d/00-enclave-builder
  # Robust source download: codeberg.org (the Calamares source host) frequently
  # resets HTTP/2 streams, which aborts makepkg's one-shot download. Give the
  # builder a curl DLAGENT that retries hard and resumes partial transfers.
  cat > /home/builder/.makepkg.conf <<'MKCONF'
DLAGENTS=('https::/usr/bin/curl -qgb "" -fLC - --retry 20 --retry-delay 3 --retry-all-errors --connect-timeout 30 -o %o %u'
          'http::/usr/bin/curl -qgb "" -fLC - --retry 20 --retry-delay 3 --retry-all-errors --connect-timeout 30 -o %o %u')
MKCONF
  chown builder:builder /home/builder/.makepkg.conf
  BUILDTMP="$(sudo -u builder mktemp -d)"
  sudo -u builder env MAKEFLAGS="-j$(nproc)" bash -euc "
    cd '$BUILDTMP'
    git clone --depth 1 https://aur.archlinux.org/calamares.git
    cd calamares
    # Skip the separate -debug package; we only ship the main one.
    OPTIONS=(!debug) makepkg -s --noconfirm --needed
  "
  cp "$BUILDTMP"/calamares/calamares-[0-9]*.pkg.tar.* "$LOCALREPO"/
  repo-add "$LOCALREPO/enclave-local.db.tar.gz" "$LOCALREPO"/calamares-[0-9]*.pkg.tar.*
  rm -rf "$BUILDTMP"
  cat >> "$PROFILE/pacman.conf" <<EOF

[enclave-local]
SigLevel = Never
Server = file://$LOCALREPO
EOF
  log "  Calamares package staged in local repo"
else
  die "makepkg not found — needed to build Calamares (install base-devel)"
fi

# --- 9. build ---
mkdir -p "$OUT"
log "running mkarchiso (this takes a while and downloads packages)…"
mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE"

[ "$KEEP_WORK" -eq 1 ] || rm -rf "$WORK"
log "done. ISO(s) in: $OUT"
ls -1 "$OUT"/*.iso 2>/dev/null || true
