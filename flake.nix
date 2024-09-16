{
  description = "A dead-simple dependency manager for Nelua";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in rec {
        packages = rec {
          "null" = pkgs.stdenv.mkDerivation {
            pname = "null";
            version = "0.2.0";
            src = ./.;

            nativeBuildInputs = with pkgs; [lua54Packages.luarocks gcc bash];
            buildInputs = with pkgs; [lua54Packages.lua libxcrypt];

            buildPhase = ''
              export LDFLAGS="-L${pkgs.libxcrypt.out}/lib"              
            
              luarocks init --lua-version=5.4
              bash bake build
            '';
          };
        };
      }
    );
}
