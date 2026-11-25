#!/usr/bin/env bash
# Enclave OS — Phase 6 (a smaller ISO: netinstall + the netboot ISO) static
# assertions. Runs anywhere.
#   * the live ISO carries the desktop preview only; the installer downloads
#     the rest of the apps (packages.netinstall) into the new system;
#   * the live preview still looks the same (stand-ins for the deferred apps);
#   * the few-MB netboot ISO boots the same live system from a GitHub Release.
# Run from the repo root:  bash tests/phase6-asserts.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fail=0
pass() { echo "PASS $1"; }
bad()  { echo "FAIL $1"; fail=1; }
has()  { if [ -f "$1" ] && grep -qE -- "$2" "$1"; then pass "$3"; else bad "$3 ($1 !~ $2)"; fi; }
lacks() { if [ -f "$1" ] && grep -qE -- "$2" "$1"; then bad "$3 ($1 =~ $2)"; else pass "$3"; fi; }
exists() { if [ -e "$1" ]; then pass "$2"; else bad "$2 (missing $1)"; fi; }
parses() { if bash -n "$1"; then pass "$2 parses"; else bad "$2 parse"; fi; }

AIR="arch/overlay/airootfs"
BIN="$AIR/usr/local/bin"
CAL="$AIR/etc/calamares"
LIVE="arch/overlay/packages.x86_64.extra"
NET="arch/overlay/packages.netinstall"
REM="arch/overlay/packages.remove"
list() { grep -vE '^\s*(#|$)' "$1"; }

# --- the split: deferred apps are downloaded, not on the ISO ---
exists "$NET" "netinstall package list"
for p in thunderbird celluloid pavucontrol wine winetricks flatpak noto-fonts lib32-mesa python-pipx; do
  has  "$NET"  "^$p\$"  "netinstall: $p"
  lacks "$LIVE" "^$p\$" "not on the live ISO: $p"
done
both=$(comm -12 <(list "$LIVE" | sort -u) <(list "$NET" | sort -u))
if [ -z "$both" ]; then pass "no package is in both lists"; else bad "in both lists: $both"; fi
has "$LIVE" '^python$'            "python stays (Calamares needs it)"
has "$LIVE" '^noto-fonts-emoji$'  "emoji font stays on the live ISO"
for p in archinstall cloud-init memtest86\\+ syslinux vim man-db iwd linux-firmware-marvell; do
  has "$REM" "^$p\$" "dropped from the live ISO: $p"
done

# --- build: packages.conf is generated from the list ---
B="scripts/build-iso.sh"
has "$B" 'packages\.netinstall'                      "build reads packages.netinstall"
has "$B" 'etc/calamares/modules/packages\.conf'      "build writes Calamares' packages.conf"
has "$B" 'backend: pacman'                           "packages module uses pacman"
has "$B" 'in both packages\.x86_64\.extra and packages\.netinstall' "build refuses a package in both lists"

# --- installer: internet required, apps downloaded between netprep and netdone ---
S="$CAL/settings.conf"
if sed -n '/^  required:/,/^  [a-zA-Z]/p' "$CAL/modules/welcome.conf" | grep -qE '^    - internet$'; then
  pass "installer requires internet"; else bad "installer requires internet (welcome.conf required:)"; fi
has "$CAL/modules/welcome.conf" '^  internetCheckUrl:'  "internet check URL set"
order=$(sed -n '/^- exec:/,/^- show:/p' "$S" | grep -nE '^  - (networkcfg|shellprocess@netprep|packages|shellprocess@netdone|unpackfs)$' | cut -d: -f2- | tr -d ' -' | tr '\n' ' ')
if [ "$order" = "unpackfs networkcfg shellprocess@netprep packages shellprocess@netdone " ]; then
  pass "exec order: unpackfs, networkcfg, netprep, packages, netdone"
else bad "exec order wrong: $order"; fi
has "$S" 'id: +netprep'                              "netprep instance"
has "$S" 'id: +netdone'                              "netdone instance"
has "$CAL/modules/shellprocess-netprep.conf" 'enclave-netinstall-prep \$\{ROOT\}' "netprep runs the prep script"
has "$CAL/modules/shellprocess-netdone.conf" 'enclave-netinstall-finish \$\{ROOT\}' "netdone runs the finish script"
parses "$BIN/enclave-netinstall-prep"   "netinstall prep"
parses "$BIN/enclave-netinstall-finish" "netinstall finish"
has "$BIN/enclave-netinstall-prep" 'multilib'          "prep enables [multilib] (Wine)"
has "$BIN/enclave-netinstall-prep" 'pacman-key --populate' "prep fills the keyring"
has "$BIN/enclave-netinstall-prep" 'geo\.mirror\.pkgbuild\.com' "prep falls back to Arch's CDN"
has "$BIN/enclave-netinstall-finish" 'resolv\.conf\.enclave-saved' "finish restores DNS"
has "$CAL/modules/shellprocess-cleanup.conf" 'enclave_http' "installed system drops the netboot hook"

# --- the live preview stays the same ---
PF="$AIR/usr/share/enclave/netinstall/preview-files"
exists "$PF" "preview stand-in list"
for f in $(list "$PF"); do
  exists "$AIR$f" "preview stand-in: $f"
done
has "$BIN/thunderbird" 'enclave-preview-app'           "Thunderbird preview stand-in"
has "$BIN/celluloid"   'enclave-preview-app'           "Media Player preview stand-in"
has "$BIN/enclave-preview-app" 'comes with Enclave OS' "stand-ins explain the app comes with the install"
exists "$AIR/usr/local/share/applications/io.github.celluloid_player.Celluloid.desktop" "Media Player still in Start"

# --- netboot: initramfs hook + the few-MB ISO ---
H="$AIR/etc/initcpio/hooks/enclave_http"
I="$AIR/etc/initcpio/install/enclave_http"
exists "$H" "enclave_http hook"
exists "$I" "enclave_http install script"
has "$H" 'enclave-airootfs\.sfs'                     "hook downloads the live image"
has "$H" 'archiso_mount_handler'                     "hook hands over to archiso"
has "$H" '/run/archiso/bootmnt'                      "hook keeps the installer's image path"
has "$I" 'add_binary curl'                           "hook ships curl"
has "$I" 'ca-certificates'                           "hook ships CA certificates (HTTPS)"
has "$B" 'archiso_pxe_http enclave_http'             "build puts the hook after archiso_pxe_http"
T="tools/make-netboot-iso.sh"
parses "$T" "netboot ISO builder"
has "$T" 'ipxe\.efi'                                 "netboot uses iPXE"
has "$T" 'autoexec\.ipxe'                            "netboot boot script"
has "$T" 'enclave_http=\\\$\{base\}'                 "netboot passes the download URL"
has "$T" 'ip=dhcp net\.ifnames=0'                    "netboot keeps eth0 stable while getting an address"
has "$B" 'make-netboot-iso\.sh'                      "build makes the netboot ISO"
has "$B" 'enclave-airootfs\.sfs'                     "build publishes the live image for netboot"
W=".github/workflows/build-iso.yml"
has "$W" 'ENCLAVE_NETBOOT_URL'                       "CI points netboot at the release"
has "$W" 'enclave-netboot\.iso'                      "CI publishes the netboot ISO"
has "$W" 'for p in 0 1 2 3 4 5 6'                    "CI runs phase 6 checks"

exit $fail
