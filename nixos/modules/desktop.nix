{ pkgs, ... }:
{
  # --- KDE Plasma 6 on Wayland, SDDM, autologin as enclave ---
  services.desktopManager.plasma6.enable = true;

  services.displayManager = {
    sddm = {
      enable = true;
      wayland.enable = true;
    };
    autoLogin = {
      enable = true;
      user = "enclave";
    };
    defaultSession = "plasma";
  };

  # --- VMware guest integration (clipboard, resize, video) ---
  virtualisation.vmware.guest.enable = true;

  # --- Core desktop apps (Plasma ships these; kept explicit) ---
  environment.systemPackages = with pkgs.kdePackages; [
    dolphin        # file manager
    systemsettings # settings
    kate           # editor
  ];

  # --- Audio ---
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
}
