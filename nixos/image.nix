# KVM-free bootable Enclave disk image via systemd-repart (no VM, no KVM).
# Produces config.system.build.image (a raw GPT image) we convert to VMDK.
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/image/repart.nix"
    ./modules/common.nix
    ./modules/branding.nix
  ];

  # Boot via systemd-boot + a Unified Kernel Image on the ESP.
  boot.loader.grub.enable = false;
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.plymouth.enable = lib.mkForce false;
  boot.uki.name = "enclave";

  # Root filesystem (matches the repart root partition label below).
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  system.image.id = "enclave";
  system.image.version = "1";

  image.repart = {
    name = "enclave";
    partitions = {
      "10-esp" = {
        contents = {
          "/EFI/BOOT/BOOTX64.EFI".source =
            "${pkgs.systemd}/lib/systemd/boot/efi/systemd-bootx64.efi";
          "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
            "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
        };
        repartConfig = {
          Type = "esp";
          Format = "vfat";
          SizeMinBytes = "256M";
        };
      };
      "20-root" = {
        storePaths = [ config.system.build.toplevel ];
        repartConfig = {
          Type = "root";
          Format = "ext4";
          Label = "nixos";
          Minimize = "guess";
        };
      };
    };
  };
}
