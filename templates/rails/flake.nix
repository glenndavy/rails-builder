# flake.nix - Unified Rails Template
{
  description = "Unified Rails template with bundler and bundix approaches";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
    rails-builder = {
      url = "github:glenndavy/rails-builder";
      flake = true;
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-ruby,
    flake-compat,
    rails-builder,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    overlays = [nixpkgs-ruby.overlays.default];

    mkPkgsForSystem = system: import nixpkgs {
      inherit system overlays;
      config.permittedInsecurePackages = ["openssl-1.1.1w"];
    };

    # Simple version for template compatibility
    version = "2.2.9-rails-template";
    gccVersion = "latest";
    opensslVersion = "3_2";

    # Shared detection functions
    detectRubyVersion = {src}: let
      rubyVersionFile = src + "/.ruby-version";
      gemfile = src + "/Gemfile";
      parseVersion = version: let
        trimmed = builtins.replaceStrings ["\n" "\r" " "] ["" "" ""] version;
        cleaned = builtins.replaceStrings ["ruby-" "ruby"] ["" ""] trimmed;
      in
        builtins.match "^([0-9]+\\.[0-9]+\\.[0-9]+)$" cleaned;
      fromRubyVersion =
        if builtins.pathExists rubyVersionFile
        then let
          version = builtins.readFile rubyVersionFile;
        in
          if parseVersion version != null
          then builtins.head (parseVersion version)
          else throw "Error: Invalid Ruby version in .ruby-version: ${version}"
        else throw "Error: No .ruby-version found in RAILS_ROOT";
      fromGemfile =
        if builtins.pathExists gemfile
        then let
          content = builtins.readFile gemfile;
          match = builtins.match ".*ruby ['\"]([0-9]+\\.[0-9]+\\.[0-9]+)['\"].*" content;
        in
          if match != null
          then builtins.head match
          else fromRubyVersion
        else fromRubyVersion;
    in
      fromGemfile;

    detectBundlerVersion = {src}: let
      gemfileLock = src + "/Gemfile.lock";
      gemfile = src + "/Gemfile";
      parseVersion = version: builtins.match "([0-9]+\\.[0-9]+\\.[0-9]+)" version;
      fromGemfileLock =
        if builtins.pathExists gemfileLock
        then let
          content = builtins.readFile gemfileLock;
          match = builtins.match ".*BUNDLED WITH\n   ([0-9.]+).*" content;
        in
          if match != null && parseVersion (builtins.head match) != null
          then builtins.head match
          else throw "Error: Invalid or missing Bundler version in Gemfile.lock"
        else throw "Error: No Gemfile.lock found";
      fromGemfile =
        if builtins.pathExists gemfile
        then let
          content = builtins.readFile gemfile;
          match = builtins.match ".*gem ['\"]bundler['\"], ['\"](~> )?([0-9.]+)['\"].*" content;
        in
          if match != null && parseVersion (builtins.elemAt match 1) != null
          then builtins.elemAt match 1
          else fromGemfileLock
        else fromGemfileLock;
    in
      fromGemfile;

    mkOutputsForSystem = system: let
      pkgs = mkPkgsForSystem system;
      rubyVersion = detectRubyVersion {src = ./.;};
      bundlerVersion = detectBundlerVersion {src = ./.;};
      rubyPackage = pkgs."ruby-${rubyVersion}";
      rubyVersionSplit = builtins.splitVersion rubyVersion;
      rubyMajorMinor = "${builtins.elemAt rubyVersionSplit 0}.${builtins.elemAt rubyVersionSplit 1}";

      gccPackage =
        if gccVersion == "latest"
        then pkgs.gcc
        else pkgs."gcc${gccVersion}";

      opensslPackage =
        if opensslVersion == "3_2"
        then pkgs.openssl_3
        else pkgs."openssl_${opensslVersion}";

      # Shared build inputs for all approaches
      universalBuildInputs = [
        rubyPackage
        opensslPackage
        pkgs.libpqxx
        pkgs.sqlite
        pkgs.libxml2
        pkgs.libxslt
        pkgs.zlib
        pkgs.libyaml
        pkgs.postgresql
        pkgs.curl
        pkgs.nodejs
      ];

      builderExtraInputs = [
        gccPackage
        pkgs.pkg-config
        pkgs.rsync
        pkgs.bundix  # For generating gemset.nix
      ];

      # Shared scripts
      manage-postgres-script = pkgs.writeShellScriptBin "manage-postgres" (import (rails-builder + /imports/manage-postgres-script.nix) {inherit pkgs;});
      manage-redis-script = pkgs.writeShellScriptBin "manage-redis" (import (rails-builder + /imports/manage-redis-script.nix) {inherit pkgs;});
      generate-dependencies-script = pkgs.writeShellScriptBin "generate-dependencies" (import (rails-builder + /imports/generate-dependencies.nix) {inherit pkgs bundlerVersion rubyPackage;});
      fix-gemset-sha-script = pkgs.writeShellScriptBin "fix-gemset-sha" (import (rails-builder + /imports/fix-gemset-sha.nix) {inherit pkgs;});

      # Bundler approach (traditional)
      bundlerBuild = (import (rails-builder + "/imports/make-rails-build.nix") {inherit pkgs;}) {
        inherit rubyVersion gccVersion opensslVersion;
        src = ./.;
        buildRailsApp = pkgs.writeShellScriptBin "make-rails-app" (import (rails-builder + /imports/make-rails-app-script.nix) {inherit pkgs rubyPackage bundlerVersion rubyMajorMinor;});
      };

      # Bundix approach (Nix bundlerEnv) - only if gemset.nix exists
      bundixBuild =
        if builtins.pathExists ./gemset.nix
        then let
          bundler = pkgs.bundler.override {
            ruby = rubyPackage;
            version = bundlerVersion;
          };
          bundlerEnv = args:
            pkgs.bundlerEnv (args // {
              ruby = rubyPackage;
              bundler = bundler;
            });

          gems = (import (rails-builder + "/imports/bundler-env-with-auto-fix.nix")) {
            inherit pkgs rubyPackage bundlerVersion;
            name = "rails-gems";
            gemdir = ./.;
            gemset = ./gemset.nix;
            autoFix = true;

            # Enhanced build inputs for native extensions
            buildInputs = with pkgs; [
              gccPackage
              pkg-config
              opensslPackage
              libxml2
              libxslt
              zlib
              libyaml
            ] ++ (if pkgs.stdenv.isDarwin then [
              pkgs.darwin.apple_sdk.frameworks.CoreServices
              pkgs.darwin.apple_sdk.frameworks.Foundation
              pkgs.libiconv
            ] else []);

            # Darwin-specific gem overrides for problematic native extensions
            gemConfig = if pkgs.stdenv.isDarwin then {
              json = attrs: {
                buildInputs = (attrs.buildInputs or []) ++ [ pkgs.libiconv ];
              };
              bootsnap = attrs: {
                buildInputs = (attrs.buildInputs or []) ++ [ pkgs.libiconv ];
              };
              msgpack = attrs: {
                buildInputs = (attrs.buildInputs or []) ++ [ pkgs.libiconv ];
              };
            } else {};
          };

          usrBinDerivation = pkgs.stdenv.mkDerivation {
            name = "usr-bin-env";
            buildInputs = [pkgs.coreutils];
            dontUnpack = true;
            installPhase = ''
              mkdir -p $out/usr/bin
              ln -sf ${pkgs.coreutils}/bin/env $out/usr/bin/env
            '';
          };
          tzinfo = pkgs.stdenv.mkDerivation {
            name = "tzinfo";
            buildInputs = [pkgs.tzdata];
            dontUnpack = true;
            installPhase = ''
              mkdir -p $out/usr/share
              ln -sf ${pkgs.tzdata}/share/zoneinfo $out/usr/share/zoneinfo
            '';
          };
          defaultShellHook = ''
            export PKG_CONFIG_PATH="${pkgs.curl.dev}/lib/pkgconfig:${pkgs.postgresql}/lib/pkgconfig"
            export LD_LIBRARY_PATH="${pkgs.curl}/lib:${pkgs.postgresql}/lib:${opensslPackage}/lib"
          '';

          bundixRailsBuild = import (rails-builder + "/imports/make-rails-nix-build.nix") {
            inherit pkgs rubyVersion gccVersion opensslVersion universalBuildInputs rubyPackage rubyMajorMinor gems gccPackage opensslPackage usrBinDerivation tzinfo defaultShellHook;
            src = ./.;
            buildRailsApp = pkgs.writeShellScriptBin "make-rails-app-with-nix" (import (rails-builder + /imports/make-rails-app-script.nix) {inherit pkgs rubyPackage bundlerVersion rubyMajorMinor;});
            nodeModules = pkgs.runCommand "empty-node-modules" {} "mkdir -p $out/lib/node_modules";
            yarnOfflineCache = pkgs.runCommand "empty-cache" {} "mkdir -p $out";
          };
        in bundixRailsBuild
        else null;

      # Shared shell hook
      defaultShellHook = ''
        export PS1="rails-shell:>"
        export PKG_CONFIG_PATH="${pkgs.curl.dev}/lib/pkgconfig:${pkgs.postgresql}/lib/pkgconfig"
        export LD_LIBRARY_PATH="${pkgs.curl}/lib:${pkgs.postgresql}/lib:${opensslPackage}/lib"
        unset RUBYLIB
      '';

      apps = {
        detectBundlerVersion = {
          type = "app";
          program = "${pkgs.writeShellScriptBin "detectBundlerVersion" ''
            echo ${bundlerVersion}
          ''}/bin/detectBundlerVersion";
        };
        detectRubyVersion = {
          type = "app";
          program = "${pkgs.writeShellScriptBin "detectRubyVersion" ''
            echo ${rubyVersion}
          ''}/bin/detectRubyVersion";
        };
        flakeVersion = {
          type = "app";
          program = "${pkgs.writeShellScript "show-version" ''
            echo 'Flake Version: ${version}'
          ''}";
        };
        generate-dependencies = {
          type = "app";
          program = "${generate-dependencies-script}/bin/generate-dependencies";
        };
        fix-gemset-sha = {
          type = "app";
          program = "${fix-gemset-sha-script}/bin/fix-gemset-sha";
        };
      };

      packages = {
        ruby = rubyPackage;
        flakeVersion = pkgs.writeText "flake-version" "Flake Version: ${version}";
        manage-postgres = manage-postgres-script;
        manage-redis = manage-redis-script;
        generate-dependencies = generate-dependencies-script;
        fix-gemset-sha = fix-gemset-sha-script;

        # Bundler approach packages
        package-with-bundler = bundlerBuild.app;
        docker-with-bundler = bundlerBuild.dockerImage;

        # Legacy aliases for compatibility
        with-bundler-railsPackage = bundlerBuild.app;
        with-bundler-dockerImage = bundlerBuild.dockerImage;
      } // (if bundixBuild != null then {
        # Bundix approach packages (only if gemset.nix exists)
        package-with-bundix = bundixBuild.app;
        docker-with-bundix = bundixBuild.dockerImage;

        # Legacy aliases for compatibility
        with-bundix-railsPackage = bundixBuild.app;
        with-bundix-dockerImage = bundixBuild.dockerImage;
      } else {});

      devShells = {
        # Bare shell with just build inputs
        bare = pkgs.mkShell {
          buildInputs = universalBuildInputs ++ builderExtraInputs;
          shellHook = defaultShellHook + ''
            export PS1="bare-shell:>"
          '';
        };

        # Default shell (same as bare)
        default = pkgs.mkShell {
          buildInputs = universalBuildInputs ++ builderExtraInputs ++ [ manage-postgres-script manage-redis-script ];
          shellHook = defaultShellHook;
        };

        # Traditional bundler approach
        with-bundler = pkgs.mkShell {
          buildInputs = universalBuildInputs ++ builderExtraInputs ++ [ manage-postgres-script manage-redis-script ];
          shellHook = defaultShellHook + ''
            export PS1="$(pwd) bundler-shell >"
            export RAILS_ROOT=$(pwd)

            # Bundle isolation - same as build scripts
            export BUNDLE_PATH=$RAILS_ROOT/vendor/bundle
            export BUNDLE_GEMFILE=$PWD/Gemfile
            export PATH=$BUNDLE_PATH/bin:$RAILS_ROOT/bin:${rubyPackage}/bin:$PATH

            echo "🔧 Traditional bundler environment:"
            echo "   bundle install  - Install gems to ./vendor/bundle"
            echo "   bundle exec     - Run commands with bundler"
            echo "   rails s         - Start server (via bundle exec)"
            echo "   Gems isolated in: ./vendor/bundle"
          '';
        };
      } // (if bundixBuild != null && builtins.pathExists ./gemset.nix then {
        # Bundix approach shell (only if gemset.nix exists)
        with-bundix = let
          # Create bundler with correct version for dependency management
          bundlerPackage = pkgs.bundler.override {
            ruby = rubyPackage;
            version = bundlerVersion;
          };

          # Use the bundlerEnv gems directly for proper closure
          bundlerEnv = (import (rails-builder + "/imports/bundler-env-with-auto-fix.nix")) {
            inherit pkgs rubyPackage bundlerVersion;
            name = "rails-bundix-env";
            gemdir = ./.;
            gemset = ./gemset.nix;
            autoFix = true;

            # Enhanced build inputs for native extensions
            buildInputs = with pkgs; [
              gccPackage
              pkg-config
              opensslPackage
              libxml2
              libxslt
              zlib
              libyaml
            ] ++ (if pkgs.stdenv.isDarwin then [
              pkgs.darwin.apple_sdk.frameworks.CoreServices
              pkgs.darwin.apple_sdk.frameworks.Foundation
              pkgs.libiconv
            ] else []);

            # Darwin-specific gem overrides for problematic native extensions
            gemConfig = if pkgs.stdenv.isDarwin then {
              json = attrs: {
                buildInputs = (attrs.buildInputs or []) ++ [ pkgs.libiconv ];
              };
              bootsnap = attrs: {
                buildInputs = (attrs.buildInputs or []) ++ [ pkgs.libiconv ];
              };
              msgpack = attrs: {
                buildInputs = (attrs.buildInputs or []) ++ [ pkgs.libiconv ];
              };
            } else {};
          };
        in pkgs.mkShell {
          # Use bundlerEnv as primary buildInput for proper closure
          buildInputs = [
            bundlerEnv
            bundlerPackage   # Correct bundler version for dependency management
            rubyPackage      # Same Ruby version as bundlerEnv
            pkgs.bundix      # For regenerating gemset.nix
            manage-postgres-script
            manage-redis-script
            # Essential system tools only
            pkgs.postgresql
            pkgs.redis
            pkgs.git
            pkgs.rsync
          ];

          shellHook = defaultShellHook + ''
            export PS1="$(pwd) bundix-shell >"
            export RAILS_ROOT=$(pwd)

            # Use bundlerEnv Ruby and gems - proper closure
            export RUBYLIB=${bundlerEnv}/lib/ruby/site_ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/site_ruby/${rubyMajorMinor}.0
            export RUBYOPT=-I${bundlerEnv}/lib/ruby/site_ruby/${rubyMajorMinor}.0

            # Proper gem paths from bundlerEnv closure
            export GEM_HOME=${bundlerEnv}/lib/ruby/gems/${rubyMajorMinor}.0
            export GEM_PATH=${bundlerEnv}/lib/ruby/gems/${rubyMajorMinor}.0

            # Binstubs from bundlerEnv + bundler + Ruby binaries
            export PATH=${bundlerEnv}/bin:${bundlerPackage}/bin:${rubyPackage}/bin:$PATH

            # Unset conflicting bundle environment
            unset BUNDLE_PATH BUNDLE_GEMFILE

            echo "🔧 Nix bundlerEnv environment:"
            echo "   rails s         - Start server (direct, no bundle exec)"
            echo "   gem list        - Show installed gems from Nix closure"
            echo ""
            echo "📦 Dependency Management:"
            echo "   bundler -v      - Show bundler version (${bundlerVersion})"
            echo "   bundle lock     - Update Gemfile.lock"
            echo "   bundle add gem  - Add new gem to Gemfile"
            echo "   bundix          - Regenerate gemset.nix from Gemfile.lock"
            echo "   fix-gemset-sha  - Fix SHA mismatches in gemset.nix"
            echo ""
            echo "🗄️ Database & Services:"
            echo "   manage-postgres start - Start PostgreSQL server"
            echo "   manage-postgres help  - Show PostgreSQL connection info"
            echo "   manage-redis start    - Start Redis server"
            echo ""
            echo "💎 Gem Environment:"
            echo "   Gems: Nix closure from gemset.nix"
            echo "   Ruby: ${rubyPackage.version} (same as bundlerEnv)"
            echo "   Bundler: ${bundlerVersion} (correct version for Gemfile.lock)"
            echo "   GEM_HOME: ${bundlerEnv}/lib/ruby/gems/${rubyMajorMinor}.0"
            echo "   No bundle exec needed - direct gem access"
          '';
        };
      } else {});
    in {
      inherit apps packages devShells;
    };
  in {
    apps = forAllSystems (system: (mkOutputsForSystem system).apps);
    packages = forAllSystems (system: (mkOutputsForSystem system).packages);
    devShells = forAllSystems (system: (mkOutputsForSystem system).devShells);
  };
}