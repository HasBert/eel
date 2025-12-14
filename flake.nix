{
  description = "Embedded Extended Languages Packages";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs =
    inputs@{ nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          ...
        }:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
        in
        {
          formatter = pkgs.nixfmt-rfc-style;

          packages = {
            local = pkgs.callPackage ./package.nix {
              version = "local";
              src = ./.;
            };
            eel-c6237da = pkgs.callPackage ./package.nix {
              version = "unstable-2025-10-29";
              src = pkgs.fetchFromGitHub {
                owner = "eclairevoyant";
                repo = "eel";
                rev = "c6237daef72a20ef23398e1ee4ecc039c6387a23";
                hash = "sha256-G4dbOd22KrPGO8SQOXfWFzLUb12Q6OoASM4Z2BFB640=";
              };
            };
            eel-3cd0542 = pkgs.callPackage ./package.nix {
              version = "unstable-2025-11-08";
              src = pkgs.fetchFromGitHub {
                owner = "eclairevoyant";
                repo = "eel";
                rev = "3cd0542ed770dd0ec24ce03dc9b5f9a47aae5ee2";
                hash = "sha256-sfsNtdO93wo0s84mmOrTvQPgf2GbmYlDUboH5ixWfUU=";
              };
            };

            default = self'.packages.local;
          };

          checks =
            let
              withSpaces = ./tests/fixtures/bash-with_spaces.nix;
              withoutSpaces = ./tests/fixtures/bash-without_spaces.nix;

              simpleExpect = ./tests/expectations/bash.expect.json;
            in
            {
              eel-local = pkgs.callPackage ./tests/eel-nix-embedded.nix {
                # currtenly the same as 3cd0542, because this is the latest on github.
                eelPkg = self'.packages.local;
                cases = [
                  {
                    name = "bash 'without spaces' works";
                    fixture = withoutSpaces;
                    expect = simpleExpect;
                    shouldFail = false;
                  }
                  {
                    name = "bash 'with spaces' works";
                    fixture = withSpaces;
                    expect = simpleExpect;
                    shouldFail = false;
                  }
                  {
                    name = "bash 'with spaces, escaped' works";
                    fixture = ./tests/fixtures/bash-with_spaces-escaped.nix;
                    expect = simpleExpect;
                    shouldFail = false;
                  }
                  {
                    name = "css 'with spaces' works";
                    fixture = ./tests/fixtures/css-with_spaces.nix;
                    expect = ./tests/expectations/css.expect.json;
                    shouldFail = false;
                  }
                  {
                    name = "css 'without spaces' works";
                    fixture = ./tests/fixtures/css-without_spaces.nix;
                    expect = ./tests/expectations/css.expect.json;
                    shouldFail = false;
                  }
                ];
              };
              # This is the latest fix on github, which fixed "nixfmt formatted tags not recognised",
              # but still does not "recognise multiline end"
              eel-c6237da = pkgs.callPackage ./tests/eel-nix-embedded.nix {
                eelPkg = self'.packages.eel-c6237da;
                cases = [
                  {
                    name = "bash 'without spaces' (broken)";
                    fixture = withoutSpaces;
                    expect = simpleExpect;
                    shouldFail = true;
                  }
                  {
                    name = "bash 'with spaces' (broken)";
                    fixture = withSpaces;
                    expect = simpleExpect;
                    shouldFail = true;
                  }
                ];
              };
              # This is the latest fix on github, which fixed "recognistion of multiline end", but reintroduced
              # "nixfmt formatted tags not recognised"
              eel-3cd0542 = pkgs.callPackage ./tests/eel-nix-embedded.nix {
                eelPkg = self'.packages.eel-3cd0542;
                cases = [
                  {
                    name = "bash 'without spaces' works";
                    fixture = withoutSpaces;
                    expect = simpleExpect;
                    shouldFail = false;
                  }
                  {
                    name = "bash 'with spaces' (broken)";
                    fixture = withSpaces;
                    expect = simpleExpect;
                    shouldFail = true;
                  }
                ];
              };
            };

          devShells.default = pkgs.mkShell {
            buildInputs = [ pkgs.nodejs ];
          };
        };

      flake = { };
    };
}
