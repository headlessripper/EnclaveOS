{
  description = "Enclave OS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
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

      packages.${system} = {
        iso = self.nixosConfigurations.enclave-iso.config.system.build.isoImage;
        default = self.nixosConfigurations.enclave-iso.config.system.build.isoImage;
      };
    };
}
