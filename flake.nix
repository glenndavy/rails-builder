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
        in
        pkgs.stdenv.mkDerivation {
          name = "rails-app";
          inherit src;
          buildInputs = [ ruby ];
          buildPhase = ''
            bundle install --path vendor/bundle
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
