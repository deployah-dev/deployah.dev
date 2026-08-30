{
  description = "deployah.dev landing and Cloudflare Worker";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    deployah.url = "github:deployah-dev/deployah";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      deployah,
      ...
    }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        deployahPkg = deployah.packages.${system}.default;
        appSet = import ./nix/apps.nix {
          inherit pkgs;
          deployah = deployahPkg;
        };
      in
      {
        formatter = pkgs.nixfmt-tree;

        apps = {
          inherit (appSet.apps) preview publish-demo;
        }
        // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          inherit (appSet.apps) demo;
        };

        packages = {
          inherit (appSet.packages) preview publish-demo;
        }
        // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          inherit (appSet.packages) demo;
        };

        devShells = {
          default = pkgs.mkShell {
            name = "deployah-dev";
            packages = [
              pkgs.nodejs_22
              deployahPkg
            ];
            shellHook = ''
              export PATH="$PWD/node_modules/.bin:$PATH"
              echo "deployah.dev: node $(node -v)" >&2
            '';
          };
        }
        // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          demo = pkgs.mkShell {
            name = "deployah-dev-demo";
            packages = appSet.demoTools ++ [ pkgs.nodejs_22 ];
            shellHook = ''
              export PATH="$PWD/node_modules/.bin:$PATH"
              root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
              export STARSHIP_CONFIG="$root/demos/tapes/starship.toml"
              export STARSHIP_CACHE="$root/demos/out/.starship-cache"
              export ZSH_SYNTAX_HIGHLIGHTING="${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
              export INTER_FONTDIR="${pkgs.inter}/share/fonts"
              echo "deployah.dev demo shell: $(deployah version)" >&2
            '';
          };
        };
      }
    );
}
