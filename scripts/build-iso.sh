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
WORK="$REPO/build/work"
PROFILE="$REPO/build/profile"
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

# --- 9. build ---
mkdir -p "$OUT"
log "running mkarchiso (this takes a while and downloads packages)…"
mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE"

[ "$KEEP_WORK" -eq 1 ] || rm -rf "$WORK"
log "done. ISO(s) in: $OUT"
ls -1 "$OUT"/*.iso 2>/dev/null || true
