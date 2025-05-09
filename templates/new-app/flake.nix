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
    flake_version = "22"; # Incremented to 22

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
      rubyShell = pkgs.mkShell {
        buildInputs = with pkgs; [
          (pkgs."ruby-${(rails-builder.lib.${system}.detectRubyVersion {src = ./.;}).dotted}")
          libyaml
          zlib
          openssl
          libxml2
          libxslt
          imagemagick
          nodejs_20
        ];
        shellHook = ''
          export GEM_HOME=$PWD/.nix-gems
          export PATH=$GEM_HOME/bin:$PATH
          mkdir -p $GEM_HOME
          echo "Ruby version: ''$(ruby --version)"
          echo "Node.js version: ''$(node --version)"
          echo "Ruby shell with build inputs. Gems are installed in $GEM_HOME."
          echo "Run 'gem install <gem>' to install gems, or use Ruby without Bundler."
        '';
      };
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
