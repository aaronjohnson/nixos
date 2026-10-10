{
  description = "System Flake for Framework Laptop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    claude-code-flake.url = "github:sadjow/claude-code-nix";
    claude-code-flake.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, claude-code-flake, ... }@inputs: {

    nixosConfigurations = {

      hadron = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit claude-code-flake; };
	modules = [
          ./configuration.nix
	];
      };
    };
  };
}