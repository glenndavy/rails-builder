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
            sha256 = "sha256-vemZkXKWoWLklWSULcIxLtmo0y/C97SWyV9t88/Mh6k="; # Your SHA256
          };
          bundler = pkgs.stdenv.mkDerivation {
            name = "bundler-2.6.8";
            buildInputs = [ ruby ];
            dontUnpack = true;
            installPhase = ''
              export HOME=$TMPDIR
              export GEM_HOME=$out/bundler_gems
              export TMP_BIN=$TMPDIR/bin
              mkdir -p $HOME $GEM_HOME $TMP_BIN
              gem install --no-document --local ${bundlerGem} --install-dir $GEM_HOME --bindir $TMP_BIN
              mkdir -p $out/bin
              cp -r $TMP_BIN/* $out/bin/
            '';
          };
        in
        pkgs.stdenv.mkDerivation {
          name = "rails-app";
          inherit src;
          buildInputs = [ ruby bundler pkgs.libyaml pkgs.openssl pkgs.nodejs pkgs.git pkgs.postgresql pkgs.redis pkgs.yarn pkgs.icu pkgs.libz pkgs.glib pkgs.libxml2 pkgs.libxslt pkgs.inetutils ];
          buildPhase = ''
            echo "***** BUILDER VERSION 0.5 *******************"
            # Set up environment
            export PATH=${bundler}/bin:$PATH
            export HOME=$TMPDIR
            export GEM_HOME=$TMPDIR/gems
            export GEM_PATH=${bundler}/bundler_gems:$GEM_HOME:vendor/bundle/ruby/3.2.0
            export BUNDLE_PATH=$TMPDIR/vendor/bundle
            export BUNDLE_USER_HOME=$TMPDIR/.bundle
            export BUNDLE_USER_CACHE=$TMPDIR/.bundle/cache
            mkdir -p $HOME $GEM_HOME $BUNDLE_PATH $BUNDLE_USER_HOME $BUNDLE_USER_CACHE
            # Debug environment
            echo "Bundler version:"
            bundle --version
            echo "PATH: $PATH"
            echo "GEM_PATH: $GEM_PATH"
            # Configure Bundler
            bundle config set --local path 'vendor/bundle'
            bundle config set --local gemfile Gemfile
            bundle config set --local without 'development test'
            bundle install --local --verbose
            # Use bundle exec to ensure rails is found
            bundle exec rails assets:precompile
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
