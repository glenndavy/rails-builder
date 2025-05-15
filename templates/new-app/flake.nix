{
  description = "Rails application using rails-builder";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rails-builder = {
      url = "github:glenndavy/rails-builder";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    rails-builder,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config = rails-builder.lib.${system}.nixpkgsConfig;
    };
    # Define gccVersion per app
    gccVersion = null; # e.g., "8" for gcc8, null for default
  in {
    packages.${system} = {
      buildRailsApp =
        (rails-builder.lib.${system}.buildRailsApp {
          src = ./.;
          gem_strategy = "bundix";
          gemset = ./gemset.nix;
          nixpkgsConfig = rails-builder.lib.${system}.nixpkgsConfig;
          gccVersion = gccVersion;
        }).app;

      default = self.packages.${system}.buildRailsApp;

      dockerImage = rails-builder.lib.${system}.mkDockerImage {
        railsApp = self.packages.${system}.buildRailsApp;
        name = "rails-app";
        ruby = pkgs."ruby-${(rails-builder.lib.${system}.detectRubyVersion {src = ./.;}).dotted}";
        bundler =
          (rails-builder.lib.${system}.buildRailsApp {
            src = ./.;
            nixpkgsConfig = rails-builder.lib.${system}.nixpkgsConfig;
            gccVersion = gccVersion;
          }).bundler;
      };
    };

    devShells.${system} = {
      default = rails-builder.lib.${system}.mkAppDevShell {
        src = ./.;
        gccVersion = gccVersion;
      };
      bundix = rails-builder.devShells.${system}.bundix;
    };

    apps.${system} = {
      builderVersion = {
        type = "app";
        program = "${pkgs.writeShellScriptBin "builder-version" ''
          #!${pkgs.runtimeShell}
          echo "${rails-builder.flake_version}"
        ''}/bin/builder-version";
      };
    };
  };
}
