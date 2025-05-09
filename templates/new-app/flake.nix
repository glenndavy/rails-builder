{
  description = "A Rails application template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rails-builder.url = "github:glenndavy/rails-builder";
  };

  outputs = {
    self,
    nixpkgs,
    rails-builder,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [rails-builder.inputs.nixpkgs-ruby.overlays.default];
    };
    nixpkgsConfig = rails-builder.lib.${system}.nixpkgsConfig;
    flake_version = "30"; # Incremented to 30

    # Rails app derivation from buildRailsApp
    railsApp =
      (rails-builder.lib.${system}.buildRailsApp {
        src = ./.;
        gem_strategy = "vendored";
        nixpkgsConfig = nixpkgsConfig;
      }).app;
  in {
    packages.${system} = {
      default = railsApp;
      bundix =
        (rails-builder.lib.${system}.buildRailsApp {
          src = ./.;
          gem_strategy = "bundix";
          gemset =
            if builtins.pathExists ./gemset.nix
            then import ./gemset.nix
            else null;
          nixpkgsConfig = nixpkgsConfig;
        }).app;
      generate-gemset = rails-builder.packages.${system}.generate-gemset;
      debugOpenssl = rails-builder.packages.${system}.debugOpenssl;
      dockerImage = rails-builder.lib.${system}.mkDockerImage {
        railsApp = railsApp;
        name = "rails-app";
      };
      dockerImageDebug = rails-builder.lib.${system}.mkDockerImage {
        railsApp = railsApp;
        name = "rails-app";
        debug = true;
      };
    };

    devShells.${system} = {
      bundix = rails-builder.devShells.${system}.bundix;
      appDevShell = rails-builder.lib.${system}.mkAppDevShell {src = ./.;};
      bootstrapDevShell = rails-builder.lib.${system}.mkBootstrapDevShell {src = ./.;};
      rubyShell = rails-builder.lib.${system}.mkRubyShell {src = ./.;};
    };

    apps.${system} = {
      default = {
        type = "app";
        program = "${railsApp}/app/bin/rails-app";
      };
      detectBundlerVersion = {
        type = "app";
        program = let
          version = rails-builder.lib.${system}.detectBundlerVersion {src = ./.;};
          script = pkgs.writeShellScriptBin "detect-bundler-version" ''
            #!${pkgs.runtimeShell}
            echo "${version}"
          '';
        in "${script}/bin/detect-bundler-version";
      };
      detectRubyVersion = {
        type = "app";
        program = let
          version = (rails-builder.lib.${system}.detectRubyVersion {src = ./.;}).dotted;
          script = pkgs.writeShellScriptBin "detect-ruby-version" ''
            #!${pkgs.runtimeShell}
            echo "${version}"
          '';
        in "${script}/bin/detect-ruby-version";
      };
      flakeVersion = {
        type = "app";
        program = "${pkgs.writeShellScriptBin "flake-version" ''
          #!${pkgs.runtimeShell}
          echo "${flake_version}"
        ''}/bin/flake-version";
      };
      builderVersion = {
        type = "app";
        program = "${rails-builder.apps.${system}.flakeVersion.program}";
      };
      bundix = {
        type = "app";
        program = "${(rails-builder.lib.${system}.buildRailsApp {
          src = ./.;
          gem_strategy = "bundix";
          gemset =
            if builtins.pathExists ./gemset.nix
            then import ./gemset.nix
            else null;
          nixpkgsConfig = nixpkgsConfig;
        }).app}/app/bin/rails-app";
      };
    };
  };
}
