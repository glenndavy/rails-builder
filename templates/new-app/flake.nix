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
    flake_version = "49"; # Incremented to 49 due to dockerImage fix

    # Rails app derivation from buildRailsApp
    railsApp =
      (rails-builder.lib.${system}.buildRailsApp {
        src = ./.;
        gem_strategy = "vendored";
        nixpkgsConfig = nixpkgsConfig;
        buildCommands = true; # Skip assets:precompile
      }).app;
    rubyVersion = rails-builder.lib.${system}.detectRubyVersion {src = ./.;};
    ruby = pkgs."ruby-${rubyVersion.dotted}";
    bundler =
      (rails-builder.lib.${system}.buildRailsApp {
        src = ./.;
        gem_strategy = "vendored";
        nixpkgsConfig = nixpkgsConfig;
      }).bundler;
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
      dockerImage = rails-builder.lib.${system}.mkDockerImage {
        railsApp = railsApp;
        name = "rails-app";
        ruby = ruby;
        bundler = bundler;
      };
      generate-gemset = pkgs.writeShellScriptBin "generate-gemset" ''
        if [ -z "$1" ]; then
          echo "Error: Please provide a source directory path."
          exit 1
        fi
        if [ ! -f "$1/Gemfile.lock" ]; then
          echo "Error: Gemfile.lock is missing in $1."
          exit 1
        fi
        cd "$1"
        ${pkgs.bundix}/bin/bundix
        if [ -f gemset.nix ]; then
          echo "Generated gemset.nix successfully."
        else
          echo "Error: Failed to generate gemset.nix."
          exit 1
        fi
      '';
      debugOpenssl = pkgs.writeShellScriptBin "debug-openssl" ''
        #!${pkgs.runtimeShell}
        echo "OpenSSL versions available:"
        nix eval --raw nixpkgs#openssl.outPath
        nix eval --raw nixpkgs#openssl_1_1.outPath 2>/dev/null || echo "openssl_1_1 not found"
        echo "Permitted insecure packages:"
        echo "${builtins.concatStringsSep ", " nixpkgsConfig.permittedInsecurePackages}"
        echo "Checking if openssl-1.1.1w is allowed:"
        nix eval --raw nixpkgs#openssl_1_1_1w.outPath 2>/dev/null || echo "openssl-1.1.1w is blocked"
      '';
    };

    devShells.${system} = {
      bundix = pkgs.mkShell {
        buildInputs = [pkgs.bundix];
        shellHook = ''
          echo "Run 'bundix' to generate gemset.nix."
        '';
      };
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
        program = "${pkgs.writeShellScriptBin "detect-bundler-version" ''
          #!${pkgs.runtimeShell}
          echo "${(rails-builder.lib.${system}.detectBundlerVersion {src = ./.;})}"
        ''}/bin/detect-bundler-version";
      };
      detectRubyVersion = {
        type = "app";
        program = "${pkgs.writeShellScriptBin "detect-ruby-version" ''
          #!${pkgs.runtimeShell}
          echo "${(rails-builder.lib.${system}.detectRubyVersion {src = ./.;}).dotted}"
        ''}/bin/detect-ruby-version";
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
        program = "${pkgs.writeShellScriptBin "builder-version" ''
          #!${pkgs.runtimeShell}
          echo "${rails-builder.flake_version}"
        ''}/bin/builder-version";
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
