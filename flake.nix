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
    version = "2.0.6"; # Backend version
    overlays = [nixpkgs-ruby.overlays.default];
    pkgs = import nixpkgs {inherit system overlays;};

    # Function to create build environment
    mkRailsBuild = {
      rubyVersion,
      bundlerVersion ? "latest",
      gccVersion ? "latest",
      opensslVersion ? "3_2",
    }: let
      rubyPackage = pkgs."ruby_${builtins.replaceStrings ["."] ["_"] rubyVersion}";
      bundlerPackage =
        if bundlerVersion == "latest"
        then pkgs.bundler
        else pkgs.bundler.override {version = bundlerVersion;};
      gccPackage =
        if gccVersion == "latest"
        then pkgs.gcc
        else pkgs."gcc${gccVersion}";
      opensslPackage = pkgs."openssl_${opensslVersion}";
    in {
      shell = pkgs.mkShell {
        buildInputs = [
          rubyPackage
          bundlerPackage
          gccPackage
          pkgs.curl
          opensslPackage
          pkgs.tzdata
          pkgs.pkg-config
          pkgs.zlib
          pkgs.libyaml
        ];
        shellHook = ''
          export PKG_CONFIG_PATH=${pkgs.curl.dev}/lib/pkgconfig
          export LD_LIBRARY_PATH=${pkgs.curl}/lib:${opensslPackage}/lib
          export TZDIR=/usr/share/zoneinfo
          mkdir -p /usr/share
          ln -sf ${pkgs.tzdata}/share/zoneinfo /usr/share/zoneinfo
        '';
      };
      app = pkgs.stdenv.mkDerivation {
        name = "rails-app";
        src = ./.; # Overridden by frontend
        buildInputs = [rubyPackage bundlerPackage gccPackage pkgs.curl opensslPackage pkgs.tzdata pkgs.pkg-config pkgs.zlib pkgs.libyaml];
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
        contents = [self.app pkgs.curl opensslPackage];
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
