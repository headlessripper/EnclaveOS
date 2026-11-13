{ lib, ... }:
let
  hostName = "enclave";
in
{
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

  # --- Hardware / firmware ---
  hardware.enableRedistributableFirmware = true;

  # --- Identity & locale ---
  networking.hostName = hostName;
  networking.networkmanager.enable = true;
  time.timeZone = lib.mkDefault "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # --- User (dev default; installer / real deploy overrides the password) ---
  users.users.enclave = {
    isNormalUser = true;
    description = "Enclave";
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "enclave";
  };

  # --- Nix / flakes on the installed system ---
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}
