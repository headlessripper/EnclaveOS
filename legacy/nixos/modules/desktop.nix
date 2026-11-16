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

  # --- Core desktop apps + Enclave theme, installed system-wide so the look
  #     applies on first boot (not only after the first login) ---
  environment.systemPackages = (with pkgs.kdePackages; [
    dolphin        # file manager
    systemsettings # settings
    kate           # editor
  ]) ++ [
    (pkgs.callPackage ../pkgs/enclave-glass-colors.nix { })
    (pkgs.callPackage ../pkgs/enclave-paper-colors.nix { })
    (pkgs.callPackage ../pkgs/enclave-icons.nix { })
    (pkgs.callPackage ../pkgs/enclave-lookandfeel.nix { })
  ];

  # System-wide Plasma defaults — colour scheme, icons, accent, global theme.
  environment.etc."xdg/kdeglobals".text = ''
    [General]
    ColorScheme=EnclaveGlass
    AccentColor=255,106,19

    [Icons]
    Theme=Enclave

    [KDE]
    LookAndFeelPackage=org.enclave.glass
    widgetStyle=Breeze
  '';
  # No KDE splash (the Enclave plymouth covers boot).
  environment.etc."xdg/ksplashrc".text = ''
    [KSplash]
    Engine=none
    Theme=None
  '';

  # --- Audio ---
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
}
