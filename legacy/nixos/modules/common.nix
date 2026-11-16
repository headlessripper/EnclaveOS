{ lib, ... }:
{
  # Shared by both the installed system and the live ISO.
  # No fileSystems / bootloader here — those are installed-system-only (base.nix),
  # because the live ISO provides its own.

  # --- Hardware / firmware ---
  hardware.enableRedistributableFirmware = true;

  # --- Identity & locale ---
  networking.hostName = lib.mkDefault "enclave";
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

  # --- Nix / flakes on the running system ---
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}
