{
  description = "Public bootstrap NixOS config: gets a fresh machine (x86_64 or Apple Silicon/Asahi) to a state where it can pull the real, private config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Asahi only. Both pins match the private config on purpose: the kernel is
    # built from these, and the same inputs give the same kernel, so switching
    # to the private config does not rebuild it.
    nixpkgs-kernel.url = "github:nixos/nixpkgs/e158d9ed9b51c98974c5e66e1ba1c9e0255fecaa";
    nixos-apple-silicon.url = "github:nix-community/nixos-apple-silicon/12cd234285d3037cedfab979aa70b75284a59afc";
    nixos-apple-silicon.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forSystems = f: nixpkgs.lib.genAttrs systems f;
      mk = system: hostModule: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs self; };
        modules = [ ./modules/base.nix hostModule ];
      };
    in
    {
      # nix run github:<you>/nixos-bootstrap#adopt-config -- OWNER/REPO [HOST]
      packages = forSystems (system: {
        adopt-config = nixpkgs.legacyPackages.${system}.callPackage ./adopt-config.nix { };
        default = self.packages.${system}.adopt-config;
      });

      nixosConfigurations.bootstrap = mk "x86_64-linux" ./modules/x86_64.nix;
      nixosConfigurations.bootstrap-asahi = mk "aarch64-linux" ./modules/asahi.nix;
    };
}
