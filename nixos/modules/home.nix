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
      home.packages = [ (pkgs.callPackage ../pkgs/enclave-icons.nix { }) ];

      programs.plasma = {
        enable = true;

        # Task 3 — Enclave look: dark + orange accent, branded wallpaper, font.
        workspace = {
          lookAndFeel = "org.kde.breezedark.desktop";
          colorScheme = "BreezeDark";
          iconTheme = "Enclave";
          wallpaper = pkgs.callPackage ../pkgs/enclave-wallpaper.nix { };
        };
        fonts.general = {
          family = "Noto Sans";
          pointSize = 10;
        };

        # Orange accent (#FF6A13 = 255,106,19); no typed option in this
        # plasma-manager, so set it via kdeglobals directly.
        configFile.kdeglobals.General.AccentColor = "255,106,19";

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
