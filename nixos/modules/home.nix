{ inputs, ... }:
{
  # home-manager as a NixOS module; declares the enclave user's Plasma desktop
  # via plasma-manager. Theme/panels/icons are added in later modules under
  # home-manager.users.enclave.programs.plasma.* (Tasks 3-5).
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };

    users.enclave = { pkgs, ... }: {
      imports = [ inputs.plasma-manager.homeManagerModules.plasma-manager ];
      home.stateVersion = "26.05";
      # Three selectable Enclave themes: Glass (default), Paper (light), and the
      # built-in dark. Glass is the signature warm-glass look.
      home.packages = [
        (pkgs.callPackage ../pkgs/enclave-icons.nix { })
        (pkgs.callPackage ../pkgs/enclave-glass-colors.nix { })  # default "Enclave Glass"
        (pkgs.callPackage ../pkgs/enclave-paper-colors.nix { })  # "Enclave Paper" light
      ];

      programs.plasma = {
        enable = true;

        # Enclave Glass: dark warm glass, orange accent, the bloom wallpaper.
        workspace = {
          lookAndFeel = "org.kde.breezedark.desktop";
          colorScheme = "EnclaveGlass";
          iconTheme = "Enclave";
          wallpaper = pkgs.callPackage ../pkgs/enclave-wallpaper.nix { };
        };
        fonts.general = {
          family = "Noto Sans";
          pointSize = 10;
        };

        configFile = {
          # Orange accent (#FF6A13 = 255,106,19); no typed option in this plasma-manager.
          kdeglobals.General.AccentColor = "255,106,19";
          # Frosted glass: blur behind translucent panels and windows.
          kwinrc."Plugins".blurEnabled = true;
          kwinrc."Effect-blur".BlurStrength = 12;
          kwinrc."Effect-blur".NoiseStrength = 3;
          # Rounded window corners.
          kwinrc."org.kde.kdecoration2".ButtonsOnLeft = "MS";
        };

        # Task 4 — a single clean floating-island taskbar: start menu,
        # running apps, system tray, clock, centered and shrunk to content.
        panels = [
          {
            location = "bottom";
            floating = true;
            lengthMode = "fit";
            alignment = "center";
            height = 44;
            widgets = [
              "org.kde.plasma.kickoff"
              "org.kde.plasma.icontasks"
              "org.kde.plasma.marginsseparator"
              "org.kde.plasma.systemtray"
              "org.kde.plasma.digitalclock"
            ];
          }
        ];
      };
    };
  };
}
