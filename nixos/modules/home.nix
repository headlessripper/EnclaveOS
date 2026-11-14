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

    users.enclave = { ... }: {
      imports = [ inputs.plasma-manager.homeManagerModules.plasma-manager ];
      home.stateVersion = "26.05";
      programs.plasma.enable = true;
    };
  };
}
