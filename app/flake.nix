{
  description = "Rails app in bank-statements";

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
    flake_version = "11"; # Incremented to 11
  in {
    packages.${system} = {
      default =
        (rails-builder.lib.${system}.buildRailsApp {
          src = ./.;
          gem_strategy = "vendored";
          nixpkgsConfig = nixpkgsConfig;
        }).app;
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
    };

    devShells.${system} = {
      bundix = rails-builder.devShells.${system}.bundix;
      appDevShell = rails-builder.devShells.${system}.appDevShell {src = ./.;};
      bootstrapDevShell = rails-builder.devShells.${system}.bootstrapDevShell {src = ./.;};
    };

    apps.${system} = {
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
        }).app}/app";
      };
    };
  };
}
