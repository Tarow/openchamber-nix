{
  description = "OpenChamber - Desktop and web interface for OpenCode AI agent";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forSystems = f: nixpkgs.lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});
    in
    {
      packages = forSystems (
        system: pkgs: {
          openchamber = pkgs.callPackage ./pkgs/openchamber { };
          openchamber-desktop = pkgs.callPackage ./pkgs/openchamber-desktop { };
          default = self.packages.${system}.openchamber;
        }
      );
    };
}
