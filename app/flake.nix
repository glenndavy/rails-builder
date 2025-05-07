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
    pkgs = import nixpkgs {inherit system;};
  in {
    packages.${system} = {
      default = rails-builder.lib.${system}.buildRailsApp {
        src = ./.;
        gem_strategy = "vendored";
      };
      bundix = rails-builder.lib.${system}.buildRailsApp {
        src = ./.;
        gem_strategy = "bundix";
        gemset =
          if builtins.pathExists ./gemset.nix
          then import ./gemset.nix
          else null;
      };
      generate-gemset = rails-builder.packages.${system}.generate-gemset;
    };

    devShells.${system}.bundix = rails-builder.devShells.${system}.bundix;

    apps.${system} = {
      detectBundlerVersion = {
        type = "app";
        program = let
          version = rails-builder.lib.${system}.detectBundlerVersion {src = ./.;};
          script = pkgs.writeScriptBin "detect-bundler-version" ''
            #!${pkgs.runtimeShell}
            echo "${version}"
          '';
        in "${script}/bin/detect-bundler-version";
      };

      detectRubyVersion = {
        type = "app";
        program = let
          version = rails-builder.lib.${system}.detectRubyVersion {src = ./.;}.dotted;
          script = pkgs.writeScriptBin "detect-ruby-version" ''
            #!${pkgs.runtimeShell}
            echo "${version}"
          '';
        in "${script}/bin/detect-ruby-version";
      };
    };
  };
}
