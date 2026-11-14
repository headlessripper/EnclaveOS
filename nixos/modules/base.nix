{ lib, ... }:
{
  # Installed-system base: disk layout + bootloader. Shared settings live in
  # common.nix; the live ISO imports common.nix directly (not this file).
  imports = [ ./common.nix ];

  # --- Platform ---
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # --- Boot: systemd-boot on UEFI ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.availableKernelModules = [
    "ahci" "xhci_pci" "nvme" "sd_mod" "sr_mod"
    "virtio_blk" "virtio_pci" "vmw_pvscsi"
  ];

  # --- Filesystems: Btrfs root (subvolumes) + FAT32 ESP, device-agnostic labels ---
  fileSystems."/" = {
    device = "/dev/disk/by-label/enclave-root";
    fsType = "btrfs";
    options = [ "subvol=@" "compress=zstd" "noatime" ];
  };
  fileSystems."/home" = {
    device = "/dev/disk/by-label/enclave-root";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd" "noatime" ];
  };
  fileSystems."/nix" = {
    device = "/dev/disk/by-label/enclave-root";
    fsType = "btrfs";
    options = [ "subvol=@nix" "compress=zstd" "noatime" ];
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ENCLAVE-ESP";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };
}
