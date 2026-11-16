# KVM-free bootable Enclave disk image via systemd-repart (no VM, no KVM).
# Produces config.system.build.image (a raw GPT image) we convert to VMDK.
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/image/repart.nix"
    ./modules/common.nix
    ./modules/branding.nix
    ./modules/desktop.nix   # Phase 1a: the Enclave Plasma desktop
    ./modules/home.nix      # plasma-manager look (theme, island taskbar, icons)
  ];

  # Boot via systemd-boot + a Unified Kernel Image on the ESP.
  boot.loader.grub.enable = false;
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.uki.name = "enclave";

  # Storage controller drivers so the initrd can see the disk in VMware/QEMU/etc.
  # (Without these the root device never appears and boot drops to emergency mode.)
  boot.initrd.availableKernelModules = [
    # VMware SCSI controllers (LSI parallel/SAS, paravirtual, BusLogic)
    "mptspi" "mptsas" "mptscsih" "vmw_pvscsi" "BusLogic" "sym53c8xx"
    # SATA/IDE/NVMe/USB
    "ahci" "ata_piix" "sd_mod" "sr_mod" "nvme" "xhci_pci" "ehci_pci" "uhci_hcd" "usbhid"
    # virtio (QEMU/KVM)
    "virtio_blk" "virtio_pci" "virtio_scsi"
  ];

  # Root filesystem (matches the repart root partition label below).
  # repart's Label= sets the GPT PARTITION label, so match on by-partlabel
  # (by-label matches the filesystem label, which repart does not set here).
  fileSystems."/" = {
    device = "/dev/disk/by-partlabel/nixos";
    fsType = "ext4";
  };

  system.image.id = "enclave";
  system.image.version = "1";

  # A second generation (adds htop), baked into the image so rollback can be
  # demonstrated entirely offline (no network, no KVM) on the booted VM.
  specialisation.withHtop.configuration = {
    environment.systemPackages = [ pkgs.htop ];
  };

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
          # Plasma needs room; give the desktop headroom to run and update.
          SizeMinBytes = "16G";
        };
      };
    };
  };
}
