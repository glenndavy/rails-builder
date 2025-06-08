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
    version = "2.0.23"; # Backend version
    overlays = [nixpkgs-ruby.overlays.default];
    pkgs = import nixpkgs {inherit system overlays;};

    # Function to create build environment
    mkRailsBuild = {
      rubyVersion,
      bundlerVersion ? "latest",
      gccVersion ? "latest",
      opensslVersion ? "3_2",
      src ? ./., # Default to current directory if not provided
    }: let
      rubyPackage = pkgs."ruby-${rubyVersion}";
      bundlerPackage = pkgs.bundler; # Use default bundler version
      gccPackage =
        if gccVersion == "latest"
        then pkgs.gcc
        else pkgs."gcc${gccVersion}";
      opensslPackage =
        if opensslVersion == "3_2"
        then pkgs.openssl_3 # Map 3_2 to openssl_3
        else pkgs."openssl_${opensslVersion}";
    in {
      shell = pkgs.mkShell {
        buildInputs = [
          rubyPackage
          bundlerPackage
          gccPackage
          opensslPackage
          pkgs.curl
          pkgs.tzdata
          pkgs.pkg-config
          pkgs.zlib
          pkgs.libyaml
          pkgs.gosu # For manage-postgres
          pkgs.postgresql # For pg gem native extension
          pkgs.rsync # For artifact copying
        ];
        shellHook = ''
          export PKG_CONFIG_PATH="${pkgs.curl.dev}/lib/pkgconfig:${pkgs.postgresql}/lib/pkgconfig"
          export LD_LIBRARY_PATH="${pkgs.curl}/lib:${pkgs.postgresql}/lib:${opensslPackage}/lib"
          export TZDIR="$HOME/zoneinfo"
          mkdir -p "$HOME/zoneinfo"
          ln -sf "${pkgs.tzdata}/share/zoneinfo" "$HOME/zoneinfo"
        '';
      };
      app = pkgs.stdenv.mkDerivation {
        name = "rails-app";
        inherit src; # Use provided src
        buildInputs = [rubyPackage bundlerPackage gccPackage opensslPackage pkgs.curl pkgs.tzdata pkgs.pkg-config pkgs.zlib pkgs.libyaml pkgs.postgresql pkgs.rsync];
        buildPhase = ''
          export HOME=/tmp
          export BUNDLE_PATH=$out/vendor/bundle
          export BUNDLE_GEMFILE=$src/Gemfile
          bundle config set --local path $BUNDLE_PATH
          bundle install
          bundle pristine curb
          bundle exec rails assets:precompile
        '';
        installPhase = ''
          mkdir -p $out
          cp -r . $out
        '';
      };
      dockerImage = pkgs.dockerTools.buildLayeredImage {
        name = "rails-app";
        tag = "latest";
        contents = [self.app pkgs.curl opensslPackage pkgs.postgresql pkgs.rsync];
        config = {
          Cmd = ["${rubyPackage}/bin/ruby" "${self.app}/bin/rails" "server" "-b" "0.0.0.0"];
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
