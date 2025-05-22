{
  description = "Rails application using rails-builder";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-historical.url = "github:NixOS/nixpkgs/23.11"; # For gcc, etc.
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
      overlays = [rails-builder.inputs.nixpkgs-ruby.overlays.default];
    };
    historicalPkgs = import nixpkgs-historical {inherit system;};
    packageOverrides = {};
    gccVersion = null;
    flake_version = "1.0.27"; # Incremented for TMPDIR fix in prepareJSBuilds

    # Pre-fetch Yarn dependencies into Nix store
    yarnCache = pkgs.stdenv.mkDerivation {
      name = "yarn-cache";
      src = ./.;
      buildInputs = [pkgs.yarn pkgs.nodejs_20];
      buildPhase = ''
        export HOME=$TMPDIR
        export YARN_CACHE_FOLDER=$TMPDIR/yarn-cache
        mkdir -p $YARN_CACHE_FOLDER
        if [ -f yarn.lock ]; then
          yarn install --verbose --frozen-lockfile --prefer-offline
          # Validate cache
          if [ -z "$(ls -A $YARN_CACHE_FOLDER)" ]; then
            echo "Error: Yarn cache is empty"
            exit 1
          fi
        else
          echo "No yarn.lock found, skipping Yarn cache"
        fi
      '';
      installPhase = ''
        mkdir -p $out
        cp -r $YARN_CACHE_FOLDER/* $out/ 2>/dev/null || echo "No Yarn cache to copy"
      '';
      outputHashMode = "recursive";
      outputHashAlgo = "sha256";
      outputHash = pkgs.lib.fakeSha256; # Replace with actual hash after first build
    };

    # Yarn dependencies (if yarn.nix exists)
    yarnDeps = pkgs.lib.optional (builtins.pathExists ./yarn.nix) (pkgs.yarn2nix-moretea.mkYarnModules {
      name = "rails-app-yarn-modules";
      pname = "rails-app-yarn-modules";
      version = "1.0.0";
      packageJSON = ./package.json;
      yarnLock = ./yarn.lock;
      yarnNix = ./yarn.nix;
    });

    # Node.js dependencies (if node-packages.nix exists)
    nodeDeps = pkgs.lib.optional (builtins.pathExists ./node-packages.nix) ((pkgs.node2nix.callPackage ./node-packages.nix {}).nodeDependencies);
  in {
    packages.${system} = {
      buildRailsApp =
        (rails-builder.lib.${system}.buildRailsApp {
          src = ./.;
          nixpkgsConfig = rails-builder.lib.${system}.nixpkgsConfig;
          gccVersion = gccVersion;
          packageOverrides = packageOverrides;
          historicalNixpkgs = nixpkgs-historical;
          extraBuildInputs = yarnDeps ++ nodeDeps ++ [yarnCache];
        }).app;

      default = self.packages.${system}.buildRailsApp;

      dockerImage = rails-builder.lib.${system}.mkDockerImage {
        railsApp = self.packages.${system}.buildRailsApp;
        name = "rails-app";
        ruby = let
          rubyVersion = rails-builder.lib.${system}.detectRubyVersion {src = ./.;};
        in
          pkgs."ruby-${rubyVersion.dotted}" or (throw "Ruby version ${rubyVersion.dotted} not found in nixpkgs-ruby");
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
      jsDev = pkgs.mkShell {
        buildInputs = with pkgs; [
          yarn
          yarn2nix
          node2nix
          nodejs_20
        ];
        shellHook = ''
          echo "JavaScript development shell with yarn, yarn2nix, and node2nix"
          echo "Run 'nix run .#prepareJSBuilds' to generate yarn.nix or node-packages.nix"
        '';
      };
    };

    apps.${system} = {
      flakeVersion = {
        type = "app";
        program = "${pkgs.writeShellScriptBin "flake-version" ''
          #!${pkgs.runtimeShell}
          echo "App flake_version: ${flake_version}"
          echo "Rails-builder flake_version: ${rails-builder.flake_version}"
        ''}/bin/flake-version";
      };
      detectBundlerVersion = {
        type = "app";
        program = "${pkgs.writeShellScriptBin "detect-bundler-version" ''
          #!${pkgs.runtimeShell}
          echo "${rails-builder.lib.${system}.detectBundlerVersion {src = ./.;}}"
        ''}/bin/detect-bundler-version";
      };
      detectRailsVersion = {
        type = "app";
        program = "${pkgs.writeShellScriptBin "detect-rails-version" ''
          #!${pkgs.runtimeShell}
          echo "${rails-builder.lib.${system}.detectRailsVersion {src = ./.;}}"
        ''}/bin/detect-rails-version";
      };
      detectRubyVersion = {
        type = "app";
        program = "${pkgs.writeShellScriptBin "detect-ruby-version" ''
          #!${pkgs.runtimeShell}
          echo "${(rails-builder.lib.${system}.detectRubyVersion {src = ./.;}).dotted}"
        ''}/bin/detect-ruby-version";
      };
      generate-gemset = {
        type = "app";
        program = "${rails-builder.packages.${system}.generate-gemset}/bin/generate-gemset";
      };
      prepareJSBuilds = {
        type = "app";
        program = "${pkgs.writeShellScriptBin "prepare-js-builds" ''
          #!${pkgs.runtimeShell}
          set -e
          echo "Preparing JavaScript dependencies..."

          # Ensure TMPDIR is set
          if [ -z "$TMPDIR" ]; then
            export TMPDIR=/tmp/nix-prepare-js-$(date +%s)
            mkdir -p $TMPDIR
            echo "TMPDIR was unset, set to $TMPDIR"
          fi

          if [ -f yarn.lock ]; then
            echo "Detected Yarn (yarn.lock found)"
            # Verify package.json and yarn.lock
            if [ ! -f package.json ]; then
              echo "Error: package.json not found"
              exit 1
            fi
            echo "Validating yarn.lock consistency..."
            ${pkgs.yarn}/bin/yarn check --verify-tree || {
              echo "Error: yarn.lock is inconsistent with package.json. Run 'yarn install' locally to fix."
              exit 1
            }
            # Populate Yarn cache in TMPDIR
            echo "Running yarn install..."
            export YARN_CACHE_FOLDER=$TMPDIR/yarn-cache
            mkdir -p $YARN_CACHE_FOLDER
            ${pkgs.yarn}/bin/yarn install --verbose --frozen-lockfile --prefer-offline || {
              echo "Error: yarn install failed. Check yarn.lock or package.json."
              exit 1
            }
            # Validate cache
            if [ -z "$(ls -A $YARN_CACHE_FOLDER)" ]; then
              echo "Error: Yarn cache is empty"
              exit 1
            fi
            echo "Yarn cache populated at: $YARN_CACHE_FOLDER"
            # Generate yarn.nix for offline use
            echo "Generating yarn.nix..."
            ${pkgs.yarn2nix}/bin/yarn2nix > yarn.nix
            if [ ! -f yarn.nix ]; then
              echo "Error: Failed to generate yarn.nix"
              exit 1
            fi
            echo "Generated yarn.nix"
          elif [ -f package-lock.json ]; then
            echo "Detected npm (package-lock.json found)"
            ${pkgs.nodejs_20}/bin/npm install
            ${pkgs.node2nix}/bin/node2nix -l package-lock.json
            mv node-packages.nix .
            echo "Generated node-packages.nix"
          else
            echo "No yarn.lock or package-lock.json found. Skipping JavaScript dependency preparation."
            exit 0
          fi

          echo "JavaScript dependency preparation complete. Commit yarn.nix or node-packages.nix to your repository."
        ''}/bin/prepare-js-builds";
      };
    };
  };
}
