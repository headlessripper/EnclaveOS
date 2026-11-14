{ modulesPath, lib, ... }:
{
  # Enclave live installer ISO: the NixOS minimal install CD + Enclave's shared
  # system settings and branding. Provides its own root FS and bootloader.
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    ./modules/common.nix
    ./modules/branding.nix
  ];

  # --- ISO identity ---
  # isoBaseName drives the output filename (isoName derives from it);
  # volumeID is the ISO9660 volume label used to mount by label.
  isoImage.isoBaseName = lib.mkForce "enclave";
  isoImage.volumeID = "ENCLAVE";
  isoImage.makeEfiBootable = true;
  isoImage.makeUsbBootable = true;
}
