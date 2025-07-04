{
  description = "Generic Rails builder flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-ruby,
    ...
  }: let
    system = "x86_64-linux";
    version = "2.0.25"; # Backend version
    overlays = [nixpkgs-ruby.overlays.default];
    pkgs = import nixpkgs {inherit system overlays;};

    # Function to create build environment
    mkRailsBuild = {
        rubyVersion,
        gccVersion ? "latest",
        opensslVersion ? "3_2",
        src ? ./.
      }: let
        rubyPackage = pkgs."ruby-${rubyVersion}";
        gccPackage =
          if gccVersion == "latest"
          then pkgs.gcc
          else pkgs."gcc${gccVersion}";
        opensslPackage =
          if opensslVersion == "3_2"
          then pkgs.openssl_3
          else pkgs."openssl_${opensslVersion}";
        app = pkgs.stdenv.mkDerivation {
          name = "rails-app";
          inherit src;
          buildInputs = [pkgs.rsync];
          installPhase = ''
            mkdir -p $out
            cp -r . $out
            if [ -d "$src/vendor/bundle" ]; then
              rsync -a --delete "$src/vendor/bundle/" "$out/vendor/bundle/"
            fi
            if [ -d "$src/public/packs" ]; then
              rsync -a --delete "$src/public/packs/" "$out/public/packs/"
            fi
          '';
        };
      in {
        shell = pkgs.mkShell {
          buildInputs = [
            rubyPackage
            gccPackage
            opensslPackage
            pkgs.curl
            pkgs.tzdata
            pkgs.pkg-config
            pkgs.zlib
            pkgs.libyaml
            pkgs.gosu
            pkgs.postgresql
            pkgs.rsync
          ];
        shellHook = ''
          export PKG_CONFIG_PATH="${pkgs.curl.dev}/lib/pkgconfig:${pkgs.postgresql}/lib/pkgconfig"
          export LD_LIBRARY_PATH="${pkgs.curl}/lib:${pkgs.postgresql}/lib:${opensslPackage}/lib"
          export TZDIR="$HOME/zoneinfo"
          mkdir -p "$HOME/zoneinfo"
          ln -sf "${pkgs.tzdata}/share/zoneinfo" "$HOME/zoneinfo"
        '';
      };
      inherit app;
      dockerImage = pkgs.dockerTools.buildLayeredImage {
        name = "rails-app";
        tag = "latest";
        contents = [app rubyPackage pkgs.curl opensslPackage pkgs.postgresql pkgs.rsync];
        config = {
          Cmd = ["${rubyPackage}/bin/ruby" "${app}/bin/rails" "server" "-b" "0.0.0.0"];
          Env = ["BUNDLE_PATH=/vendor/bundle" "RAILS_ENV=production"];
          ExposedPorts = {"3000/tcp" = {};};
        };
      };
    };
  in {
    lib = {
      inherit mkRailsBuild;
      version = version;
    };
    templates.new-app = {
      path = ./templates/new-app;
      description = "A template for a Rails application";
    };
  };
}
