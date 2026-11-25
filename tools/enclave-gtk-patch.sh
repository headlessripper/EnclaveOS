#!/usr/bin/env bash
# Enclave OS — turn the pinned Fluent GTK theme source into Enclave Ember
# before it is built (scripts/build-iso.sh, step 6b):
#   * accent: Ember (#FF7A1A on dark, Burnt Orange #E95B16 on light for
#     contrast on white) instead of Material orange;
#   * surfaces: Porcelain / white in light, Obsidian / Graphite in dark;
#   * the global rule — every button, entry and control is rounded: 10 px
#     corners on controls, 14 px on windows (Fluent's "round" was 4 / 8).
#   tools/enclave-gtk-patch.sh <fluent-src-dir>
set -euo pipefail
S="${1:?Fluent-gtk-theme source dir}"
C="$S/src/_sass/_colors.scss"
V="$S/src/_sass/_variables.scss"
die() { echo "enclave-gtk-patch: $*" >&2; exit 1; }
[ -f "$C" ] && [ -f "$V" ] || die "not a Fluent-gtk-theme tree: $S"

# (quotes inside the patterns are matched with "." so the sed scripts can
#  stay in single quotes)
sed -i -E \
  -e 's/(\$theme == .orange.\) \{ @return )\$orange-700;/\1#E95B16;/' \
  -e 's/(\$theme == .orange.\) \{ @return )\$orange-600;/\1#FF7A1A;/' \
  -e 's/^(\$background:[[:space:]]+if\(\$variant == .light., )#F2F2F2, #333333\)/\1#F7F6F3, #1A1C21)/' \
  -e 's/^(\$surface:[[:space:]]+if\(\$variant == .light., )#FFFFFF, #3C3C3C\)/\1#FFFFFF, #272A31)/' \
  -e 's/^(\$base:[[:space:]]+if\(\$variant == .light., )#FFFFFF, #2B2B2B\)/\1#FFFFFF, #16181C)/' \
  -e 's/^(\$base-alt:[[:space:]]+if\(\$variant == .light., )#FAFAFA, #303030\)/\1#FAF9F6, #1D1F24)/' \
  -e 's/(\$variant == .dark. and \$state==.normal.\) \{ @return )#202020;/\1#16181C;/' \
  -e 's/(\$variant == .dark. and \$state==.backdrop.\) \{ @return )#2C2C2C;/\1#1A1C21;/' \
  -e 's/(\$state==.normal. and \$blur == .false.\) \{ @return )#F7F7F7;/\1#F7F6F3;/' \
  -e 's/(\$state==.backdrop. and \$blur == .false.\) \{ @return )#F2F2F2;/\1#F2F1EE;/' \
  "$C"
sed -i -E \
  -e 's/^(\$window-radius: if\(\$window == .round., )8px/\114px/' \
  -e 's/^(\$corner-radius: if\(\$window == .round., )4px/\110px/' \
  "$V"

# every edit must have landed — a new Fluent revision fails loudly here
for want in '#E95B16;' '#FF7A1A;' '#F7F6F3, #1A1C21' '#FFFFFF, #272A31' '#FFFFFF, #16181C' '#FAF9F6, #1D1F24' '@return #16181C;'; do
  grep -qF "$want" "$C" || die "colour patch '$want' did not apply"
done
grep -qF "'round', 14px" "$V" || die "window radius patch did not apply"
grep -qF "'round', 10px" "$V" || die "control radius patch did not apply"
echo "enclave-gtk-patch: Fluent -> Enclave Ember (accent, surfaces, 10/14 px corners)"
