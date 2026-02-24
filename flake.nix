{
  description = "Checks for nix flakes";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/x86_64-linux";
    utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      utils,
      ...
    }:
    utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        mkCheck =
          name: code: path:
          pkgs.runCommand name { } ''
            cd ${path}
            echo Running check ${name}
            ${code}
            mkdir "$out"
          '';
        mkNixCheck =
          path:
          pkgs.runCommand "check-nix" { } ''
            cd ${path}
            echo Running check nix
            ${pkgs.deadnix}/bin/deadnix --fail
            ${pkgs.statix}/bin/statix check
            mkdir "$out"
          '';
      in
      {
        lib = {
          checks = {
            nix = mkNixCheck;
            #statix = mkCheck "statix-check" "${pkgs.statix}/bin/statix check";
            #deadnix = mkCheck "deadnix-check" "${pkgs.deadnix}/bin/deadnix --fail";
          };
        };
      }
    );
}
