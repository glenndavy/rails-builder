{
  description = "Rails app builder flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
  };

  outputs = { self, nixpkgs, nixpkgs-ruby }: let
    forAllSystems = f: nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ] (system: f system);
  in {
    lib = {
      buildRailsApp = { system, rubyVersion, src, gems }: 
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ nixpkgs-ruby.overlays.default ];
          };
          rubyVersionDotted = builtins.replaceStrings ["_"] ["."] rubyVersion;
          ruby = pkgs."ruby-${rubyVersionDotted}";
          # Pre-fetch Bundler 2.6.8
          bundlerGem = pkgs.fetchurl {
            url = "https://rubygems.org/downloads/bundler-2.6.8.gem";
            sha256 = "sha256-vemZkXKWoWLklWSULcIxLtmo0y/C97SWyV9t88/Mh6k="; # Verified from rubygems.org
            #06f56f7f4c7aa76b7cb3ab9f5f3cb3c6f3cb83a7f8b5a7848d76169c0b4dd4f9
          };
          bundler = pkgs.stdenv.mkDerivation {
            name = "bundler-2.6.8";
            buildInputs = [ ruby ];
            dontUnpack = true;
            installPhase = ''
              mkdir -p $out/bin
              gem install --no-document --local ${bundlerGem} --bindir $out/bin
            '';
          };
        in
        pkgs.stdenv.mkDerivation {
          name = "rails-app";
          inherit src;
          buildInputs = [ ruby bundler ];
          buildPhase = ''
            echo "***** BUILDER VERSION 0.2 *******************"
            # Isolate all gem-related paths
            export HOME=$TMPDIR
            export GEM_HOME=$TMPDIR/gems
            export GEM_PATH=$GEM_HOME
            export BUNDLE_PATH=$TMPDIR/vendor/bundle
            export BUNDLE_USER_HOME=$TMPDIR/.bundle
            export BUNDLE_USER_CACHE=$TMPDIR/.bundle/cache
            mkdir -p $HOME $GEM_HOME $BUNDLE_PATH $BUNDLE_USER_HOME $BUNDLE_USER_CACHE
            # Configure Bundler to use vendored gems
            bundle config set --local path 'vendor/bundle'
            bundle config set --local gemfile Gemfile
            bundle config set --local without 'development test'
            bundle install --local --verbose
            rails assets:precompile
          '';
          installPhase = ''
            mkdir -p $out
            cp -r . $out
          '';
        };

      nixosModule = { railsApp, ... }: {
        imports = [ ./nixos-module.nix ];
        config.deployment.railsApp = railsApp;
      };

      dockerImage = { system, railsApp }: 
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.dockerTools.buildImage {
          name = "rails-app";
          tag = "latest";
          contents = [ railsApp ];
          config = {
            Cmd = [ "${railsApp}/bin/bundle" "exec" "puma" "-C" "config/puma.rb" ];
            ExposedPorts = { "3000/tcp" = {}; };
          };
        };
    };
  };
}
