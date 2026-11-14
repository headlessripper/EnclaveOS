{
  description = "Enclave OS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.nixos-generators = {
    url = "github:nix-community/nixos-generators";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixos-generators }:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations.enclave = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./nixos/configuration.nix ];
      };

      nixosConfigurations.enclave-iso = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./nixos/iso.nix ];
      };

      nixosConfigurations.enclave-diskimage = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./nixos/image.nix ];
      };

      packages.${system} = {
        iso = self.nixosConfigurations.enclave-iso.config.system.build.isoImage;
        default = self.nixosConfigurations.enclave-iso.config.system.build.isoImage;

        # Pre-installed, ready-to-boot VMware disk image (no in-VM install needed).
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
      };
    };
}
