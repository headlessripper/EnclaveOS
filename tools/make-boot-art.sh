#!/usr/bin/env bash
# Enclave OS — render the boot look: the GRUB boot-menu theme and the Plymouth
# splash images, from the SVG sources in arch/boot/art and arch/branding.
#
#   tools/make-boot-art.sh <grub-theme-dir> <plymouth-theme-dir> [version] [installed-grub-theme-dir]
#
# The optional last directory gets the installed system's variant of the menu
# (normally hidden; Esc shows it): wider, room for its three entries
# ("Enclave OS", "Advanced options…", "UEFI Firmware Settings"), quieter
# unselected entries, no "Live" label.
# Both share one background, mark and wordmark at the same place on screen,
# so the menu dissolves into the splash with nothing jumping. Needs
# rsvg-convert, grub-mkfont and the Inter font (used by build-iso.sh and the
# QEMU boot preview test).
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
ART="$REPO/arch/boot/art"
BRAND="$REPO/arch/branding"
G="${1:?grub theme dir}"
P="${2:?plymouth theme dir}"
VERSION="${3:-}"
INSTALLED="${4:-}"

die() { echo "make-boot-art: $*" >&2; exit 1; }
command -v rsvg-convert >/dev/null || die "rsvg-convert missing (librsvg)"
command -v grub-mkfont  >/dev/null || die "grub-mkfont missing (grub)"
fontfile() { fc-match -f '%{file}' "$1" 2>/dev/null; }
INTER="$(fontfile 'Inter')"
case "$INTER" in *[Ii]nter*) ;; *) die "Inter font missing (inter-font)";; esac
MONO="$(fontfile 'JetBrains Mono')"; case "$MONO" in *JetBrains*) ;; *) MONO="$(fontfile 'DejaVu Sans Mono')";; esac

svg() { rsvg-convert "$@"; }       # svg [-w W -h H] in.svg -o out.png
from_string() {                     # from_string out.png <<< '<svg…>'
  local out="$1"; svg -o "$out" /dev/stdin
}

# slice9 PREFIX DIR WIDTH HEIGHT L T R B — cut an SVG (stdin) into the nine
# pieces GRUB stretches (nw n ne w c e sw s se). Edge pieces are cut 4 px
# wide/tall where GRUB stretches them.
slice9() {
  local pre="$1" dir="$2" W="$3" H="$4" L="$5" T="$6" R="$7" B="$8" src
  src="$(cat)"
  local cw=$((W - L - R)) ch=$((H - T - B))
  piece() { # name x y w h
    printf '%s' "$src" | sed -E "0,/<svg /s//<svg viewBox=\"$2 $3 $4 $5\" width=\"$4\" height=\"$5\" /" \
      | svg -o "$dir/${pre}_$1.png" /dev/stdin
  }
  piece nw 0 0 "$L" "$T";            piece n  "$L" 0 4 "$T";            piece ne $((W - R)) 0 "$R" "$T"
  piece w  0 "$T" "$L" "$ch";        piece c  "$L" "$T" 4 "$ch";        piece e  $((W - R)) "$T" "$R" "$ch"
  piece sw 0 $((H - B)) "$L" "$B";   piece s  "$L" $((H - B)) 4 "$B";   piece se $((W - R)) $((H - B)) "$R" "$B"
  : "$cw"
}

# ---------------------------------------------------------------- GRUB
install -d "$G" "$G/icons"
svg -w 1920 -h 1080 "$ART/background.svg" -o "$G/background.png"
svg -w 128 -h 128 "$BRAND/enclave-logo-dark.svg" -o "$G/logo.png"
svg "$ART/wordmark.svg" -o "$G/wordmark.png"
# the menu entry's icon: the mark in white, on the ember pill
# (51 px wide, mark at the right: GRUB left-aligns entries, and the extra
# room centres icon + "Start Enclave OS" inside the pill)
from_string "$G/icons/enclave.png" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="51" height="26" viewBox="-51 0 51 26">
  <g transform="translate(-26 0) scale(0.26)">$(sed -n '/<path\|<circle/p' "$BRAND/enclave-logo-dark.svg" | sed 's/#ff6b1a/#ffffff/I')</g>
</svg>
SVG

# Selected entry: an ember pill (360x56, fully rounded) with a soft top light.
slice9 select "$G" 360 56 28 8 28 8 <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="f" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FF8A2E"/><stop offset="1" stop-color="#EC6014"/>
    </linearGradient>
    <linearGradient id="l" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.30"/><stop offset="0.45" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <rect x="0" y="0" width="360" height="56" rx="28" fill="url(#f)"/>
  <rect x="0.75" y="0.75" width="358.5" height="54.5" rx="27.25" fill="none" stroke="url(#l)" stroke-width="1.5"/>
</svg>
SVG

# Edit / command-line box: a graphite card with a hairline border.
slice9 term "$G" 120 120 16 16 16 16 <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg">
  <rect x="0.5" y="0.5" width="119" height="119" rx="15.5" fill="#15171B" fill-opacity="0.97" stroke="#2C2F36"/>
</svg>
SVG

# Fonts (GRUB draws text from pre-rendered bitmap fonts). The theme names them
# "Enclave Regular 16", "Enclave Strong Regular 20", "Enclave Mono Regular 16".
mkfont() { # quiet unless it fails (Inter's OpenType features make it chatty)
  local out; out="$(grub-mkfont "$@" 2>&1)" || { printf '%s\n' "$out" >&2; die "grub-mkfont $*"; }
}
mkfont -i 0  -s 16 -n "Enclave" -o "$G/enclave-16.pf2" "$INTER"                # Inter Regular
mkfont -i 0  -s 14 -n "Enclave" -o "$G/enclave-14.pf2" "$INTER"
mkfont -i 12 -s 20 -n "Enclave Strong" -o "$G/enclave-strong-20.pf2" "$INTER"   # Inter SemiBold
mkfont -s 16 -n "Enclave Mono" -o "$G/enclave-mono-16.pf2" "$MONO"
sed "s/%VERSION%/${VERSION}/g" "$REPO/arch/boot/grub/theme.txt" > "$G/theme.txt"

# ------------------------------------------------------------ Plymouth
install -d "$P"
cp "$G/background.png" "$G/wordmark.png" "$G/logo.png" "$P/"
# breathing glow behind the mark
from_string "$P/glow.png" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="360" height="360">
  <defs><radialGradient id="g" cx="180" cy="180" r="180" gradientUnits="userSpaceOnUse">
    <stop offset="0" stop-color="#FF7A1A" stop-opacity="0.24"/>
    <stop offset="0.15" stop-color="#FF7A1A" stop-opacity="0.215"/>
    <stop offset="0.3" stop-color="#FF7A1A" stop-opacity="0.16"/>
    <stop offset="0.45" stop-color="#FF7A1A" stop-opacity="0.1"/>
    <stop offset="0.6" stop-color="#FF7A1A" stop-opacity="0.055"/>
    <stop offset="0.75" stop-color="#FF7A1A" stop-opacity="0.025"/>
    <stop offset="0.9" stop-color="#FF7A1A" stop-opacity="0.008"/>
    <stop offset="1" stop-color="#FF7A1A" stop-opacity="0"/>
  </radialGradient></defs>
  <rect width="360" height="360" fill="url(#g)"/>
</svg>
SVG
# progress: a rounded track, the ember fill, and a light that runs along it
from_string "$P/track.png" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="220" height="4"><rect width="220" height="4" rx="2" fill="#FFFFFF" fill-opacity="0.10"/></svg>
SVG
from_string "$P/fill.png" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="220" height="4">
  <defs><linearGradient id="f"><stop offset="0" stop-color="#E95B16"/><stop offset="1" stop-color="#FFAC55"/></linearGradient></defs>
  <rect width="220" height="4" rx="2" fill="url(#f)"/>
</svg>
SVG
from_string "$P/spark.png" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="4">
  <defs><linearGradient id="s"><stop offset="0" stop-color="#FFD0A6" stop-opacity="0"/>
    <stop offset="0.6" stop-color="#FFE6CF" stop-opacity="0.95"/><stop offset="1" stop-color="#FFD0A6" stop-opacity="0"/></linearGradient></defs>
  <rect width="48" height="4" rx="2" fill="url(#s)"/>
</svg>
SVG
# passphrase field, its dots and a lock
from_string "$P/field.png" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="340" height="48">
  <rect x="0.5" y="0.5" width="339" height="47" rx="13.5" fill="#1A1C21" fill-opacity="0.92" stroke="#FF7A1A" stroke-opacity="0.55"/>
</svg>
SVG
from_string "$P/bullet.png" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><circle cx="5" cy="5" r="4.5" fill="#F5F3EF"/></svg>
SVG
from_string "$P/lock.png" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18" fill="none">
  <rect x="3" y="8" width="12" height="8.5" rx="2.2" fill="#FFAC55"/>
  <path d="M5.8 8V5.9a3.2 3.2 0 0 1 6.4 0V8" stroke="#FFAC55" stroke-width="1.7"/>
</svg>
SVG

# --------------------------------------------- installed-system GRUB variant
if [ -n "$INSTALLED" ]; then
  rm -rf "$INSTALLED"; install -d "$(dirname "$INSTALLED")"
  cp -a "$G" "$INSTALLED"
  sed -i -e 's/^  left = 50%-152$/  left = 50%-230/' \
         -e 's/^  width = 304$/  width = 460/' \
         -e 's/^  height = 58$/  height = 184/' \
         -e 's/^  item_spacing = 0$/  item_spacing = 18/' \
         -e 's/^  item_color = "#F5F3EF"$/  item_color = "#A7A39B"/' \
         -e 's/^  item_font = "Enclave Strong Regular 20"$/  item_font = "Enclave Regular 16"/' \
         -e 's/^  top = 58%+84$/  top = 58%+214/' "$INSTALLED/theme.txt"
  sed -i "s/^  text = \"${VERSION}\"$/  text = \"\"/" "$INSTALLED/theme.txt"
  for want in 'width = 460' 'height = 184' 'item_spacing = 18' 'top = 58%+214' 'item_font = "Enclave Regular 16"'; do
    grep -qF "$want" "$INSTALLED/theme.txt" || die "installed theme: '$want' not applied"
  done
fi

echo "make-boot-art: GRUB theme -> $G, splash -> $P${INSTALLED:+, installed GRUB theme -> $INSTALLED}"
