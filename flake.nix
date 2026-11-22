{
  description = "System Flake for Framework Laptop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    claude-code-flake.url = "github:sadjow/claude-code-nix";
    claude-code-flake.inputs.nixpkgs.follows = "nixpkgs";
    jantar.url = "github:aaronjohnson/jantar/dhruva";
    jantar.inputs.nixpkgs.follows = "nixpkgs";
    misra.url = "github:aaronjohnson/misra/v0.8.0";
    misra.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, claude-code-flake, jantar, misra, ... }@inputs: {

    nixosConfigurations = {

      hadron = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit claude-code-flake; };
	modules = [
          ./configuration.nix
          jantar.nixosModules.default            # dashboard on VT12
          misra.nixosModules.default             # sensor cross-checks
	];
      };
    };
  };
}
