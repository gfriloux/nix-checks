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
        pkgs-unfree = import nixpkgs { inherit system; config.allowUnfree = true; };
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
            ${pkgs.alejandra}/bin/alejandra --check .
            mkdir "$out"
          '';
        mkTerraformCheck =
          path:
          pkgs.runCommand "check-terraform" { } ''
            cd ${path}
            echo Running check terraform
            ${pkgs-unfree.terraform}/bin/terraform fmt -diff -write=false -check -recursive
            ${pkgs.tflint}/bin/tflint --recursive
            ${pkgs.findutils}/bin/find . -type d | ${pkgs.findutils}/bin/xargs -I {} -t ${pkgs.tfsec}/bin/tfsec --exclude-downloaded-modules {}
            mkdir "$out"
          '';
        mkAnsibleCheck =
          path:
          pkgs.runCommand "check-ansible" { } ''
            cd ${path}
            echo Running check ansible
            set -euo pipefail
            export HOME="$TMPDIR"
            export ANSIBLE_LOCAL_TEMP="$TMPDIR/.ansible/tmp"
            export ANSIBLE_REMOTE_TEMP="$TMPDIR/.ansible/remote_tmp"
            mkdir -p "$ANSIBLE_LOCAL_TEMP" "$ANSIBLE_REMOTE_TEMP"
            ${pkgs.ansible-lint}/bin/ansible-lint --offline --profile production --exclude tests .
            mkdir "$out"
          '';
      in
      {
        lib = {
          checks = {
            nix = mkNixCheck;
            terraform = mkTerraformCheck;
            ansible = mkAnsibleCheck;
            gitleaks = mkCheck "check-gitleaks" "${pkgs.gitleaks}/bin/gitleaks dir --no-banner --verbose --redact";
          };
        };
      }
    );
}
