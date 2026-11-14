{
  description = "Enclave OS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.nixos-generators = {
    url = "github:nix-community/nixos-generators";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.home-manager = {
    url = "github:nix-community/home-manager/release-26.05";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.plasma-manager = {
    url = "github:nix-community/plasma-manager";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.home-manager.follows = "home-manager";
  };

  outputs = inputs@{ self, nixpkgs, nixos-generators, home-manager, plasma-manager }:
    let
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
    in {
      nixosConfigurations.enclave = nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = [ ./nixos/configuration.nix ];
      };

      nixosConfigurations.enclave-iso = nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = [ ./nixos/iso.nix ];
      };

      nixosConfigurations.enclave-diskimage = nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = [ ./nixos/image.nix ];
      };

      packages.${system} = {
        iso = self.nixosConfigurations.enclave-iso.config.system.build.isoImage;
        default = self.nixosConfigurations.enclave-iso.config.system.build.isoImage;

        # KVM-free pre-installed VMware image (nixos-generators; needs KVM to build).
        vmdk = nixos-generators.nixosGenerate {
          inherit system;
          format = "vmware";
          modules = [
            ./nixos/modules/common.nix
            ./nixos/modules/branding.nix
          ];
        };

        # KVM-free bootable raw image via systemd-repart (no VM / no KVM).
        diskimage = self.nixosConfigurations.enclave-diskimage.config.system.build.image;

        # Branding packages (exposed for testing/reuse).
        enclave-icons = nixpkgs.legacyPackages.${system}.callPackage ./nixos/pkgs/enclave-icons.nix { };
      };
    };
}
