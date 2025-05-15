{
  description = "Rails application using rails-builder";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-historical.url = "github:NixOS/nixpkgs/23.11"; # Example historical nixpkgs with gcc8
    rails-builder = {
      url = "github:glenndavy/rails-builder";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-historical,
    rails-builder,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config = rails-builder.lib.${system}.nixpkgsConfig;
    };
    historicalPkgs = import nixpkgs-historical {inherit system;};
    # Define package overrides
    packageOverrides = {
      gcc = historicalPkgs.gcc8; # Override gcc with gcc8 from nixpkgs 23.11
    };
    gccVersion = null; # Optional, use if not overriding with historical nixpkgs
  in {
    packages.${system} = {
      buildRailsApp =
        (rails-builder.lib.${system}.buildRailsApp {
          src = ./.;
          gem_strategy = "bundix";
          gemset = ./gemset.nix;
          nixpkgsConfig = rails-builder.lib.${system}.nixpkgsConfig;
          gccVersion = gccVersion;
          packageOverrides = packageOverrides;
          historicalNixpkgs = nixpkgs-historical;
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
            packageOverrides = packageOverrides;
            historicalNixpkgs = nixpkgs-historical;
          }).bundler;
      };
    };

    devShells.${system} = {
      default = rails-builder.lib.${system}.mkAppDevShell {
        src = ./.;
        gccVersion = gccVersion;
        packageOverrides = packageOverrides;
        historicalNixpkgs = nixpkgs-historical;
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
