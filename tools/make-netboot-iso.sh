#!/usr/bin/env bash
# Enclave OS — the netboot ISO: a ~2 MB boot disk that starts the same live
# Enclave OS desktop by downloading it.
#
# It holds only iPXE (Arch's ipxe package, UEFI) and a boot script. At boot
# iPXE gets an address by DHCP (wired network), downloads the kernel and
# initramfs over HTTPS from BASE_URL, and the initramfs (enclave_http hook)
# then downloads the live system image (enclave-airootfs.sfs) into RAM and
# boots it: same desktop, same installer.
#
#   tools/make-netboot-iso.sh OUT.iso BASE_URL [extra kernel parameters]
#
# BASE_URL ends with "/" and serves (e.g. a GitHub Release's download URL):
#   enclave-vmlinuz  enclave-initramfs.img  enclave-airootfs.sfs
# Needs: ipxe, xorriso, mtools, dosfstools.
set -euo pipefail
OUT="${1:?usage: make-netboot-iso.sh OUT.iso BASE_URL [kernel params]}"
BASE="${2:?BASE_URL}"
EXTRA="${3:-}"
case "$BASE" in */) ;; *) BASE="$BASE/" ;; esac
IPXE="${IPXE_EFI:-/usr/share/ipxe/x86_64/ipxe.efi}"
die() { echo "make-netboot-iso: $*" >&2; exit 1; }
[ -f "$IPXE" ] || die "iPXE not found at $IPXE (pacman -S ipxe)"
for t in xorriso mformat mcopy mmd mkfs.fat; do command -v "$t" >/dev/null || die "$t not found"; done

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
# Same quiet boot as the live ISO's GRUB entry (arch/boot/grub/grub.cfg).
# net.ifnames=0 (as Arch's own netboot): udev would otherwise rename eth0
# while the initramfs is still getting an address on it.
QUIET="quiet splash loglevel=3 rd.udev.log_level=3 rd.systemd.show_status=false systemd.show_status=false vt.global_cursor_default=0"
cat > "$T/autoexec.ipxe" <<EOF
#!ipxe
# Enclave OS netboot (tools/make-netboot-iso.sh)
set base ${BASE}
:start
echo
echo    Enclave OS
echo    Starting from the internet. Keep the network cable connected.
echo
dhcp || goto nonet
echo    Downloading the Enclave OS kernel...
kernel \${base}enclave-vmlinuz initrd=enclave-initramfs.img archisobasedir=enclave enclave_http=\${base} ip=dhcp net.ifnames=0 BOOTIF=01-\${netX/mac:hexhyp} ${QUIET} ${EXTRA} || goto failed
initrd \${base}enclave-initramfs.img || goto failed
echo    Starting Enclave OS (the desktop downloads next, about a minute on a fast connection)...
boot || goto failed
:nonet
echo    No network. Connect an Ethernet cable, then press any key to try again.
prompt
goto start
:failed
echo    The download failed. Press any key to try again.
prompt
goto start
EOF

# (tests can boot their own script instead: ENCLAVE_IPXE_SCRIPT=file)
[ -n "${ENCLAVE_IPXE_SCRIPT:-}" ] && cp -f "$ENCLAVE_IPXE_SCRIPT" "$T/autoexec.ipxe"

# The EFI system partition image: iPXE as the default UEFI loader, and the
# script beside it (iPXE runs autoexec.ipxe from the disk it booted from).
dd if=/dev/zero of="$T/efiboot.img" bs=1K count=2048 status=none
mkfs.fat -n ENCLAVE_NET "$T/efiboot.img" >/dev/null
mmd -i "$T/efiboot.img" ::/EFI ::/EFI/BOOT
mcopy -i "$T/efiboot.img" "$IPXE" ::/EFI/BOOT/BOOTX64.EFI
mcopy -i "$T/efiboot.img" "$T/autoexec.ipxe" ::/autoexec.ipxe
mcopy -i "$T/efiboot.img" "$T/autoexec.ipxe" ::/EFI/BOOT/autoexec.ipxe

mkdir -p "$T/root"
cat > "$T/root/README.txt" <<EOF
Enclave OS netboot disk.
Boot this (UEFI) with a wired internet connection: it downloads and starts
the live Enclave OS desktop from
  ${BASE}
Needs 4 GB of memory or more (the live system runs from RAM).
EOF

# UEFI-only hybrid image (CD/DVD and USB stick), laid out like archiso's:
# the ESP is an appended GPT partition and the El Torito boot image.
xorriso -as mkisofs -quiet \
  -iso-level 3 -full-iso9660-filenames -joliet -rational-rock \
  -volid ENCLAVE_NETBOOT -appid "Enclave OS netboot" -publisher "Enclave OS" \
  -append_partition 2 C12A7328-F81F-11D2-BA4B-00A0C93EC93B "$T/efiboot.img" \
  -appended_part_as_gpt \
  -eltorito-alt-boot -e --interval:appended_partition_2:all:: -no-emul-boot \
  -output "$OUT" "$T/root"
echo "make-netboot-iso: $(du -h "$OUT" | cut -f1) $OUT -> $BASE"
