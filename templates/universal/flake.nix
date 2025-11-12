# flake.nix - Universal Ruby Application Template
{
  description = "Universal Ruby application template with smart dependency detection (Rails, Hanami, Sinatra, Rack, Ruby)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
    ruby-builder = {
      url = "github:glenndavy/rails-builder"; # Will be renamed
      flake = true;
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-ruby,
    flake-compat,
    ruby-builder,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    overlays = [nixpkgs-ruby.overlays.default];

    mkPkgsForSystem = system:
      import nixpkgs {
        inherit system overlays;
        config.permittedInsecurePackages = ["openssl-1.1.1w"];
      };

    version = "3.0.0-universal-template";
    gccVersion = "latest";
    opensslVersion = "3_2";

    # Import framework detection
    detectFramework = import (ruby-builder + "/imports/detect-framework.nix");

    # Shared detection functions (same as Rails template)
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
        else throw "Error: No .ruby-version found in APP_ROOT";
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
    in
      fromGemfileLock;

    mkOutputsForSystem = system: let
      pkgs = mkPkgsForSystem system;
      rubyVersion = detectRubyVersion {src = ./.;};
      bundlerVersion = detectBundlerVersion {src = ./.;};
      rubyPackage = pkgs."ruby-${rubyVersion}";
      rubyVersionSplit = builtins.splitVersion rubyVersion;
      rubyMajorMinor = "${builtins.elemAt rubyVersionSplit 0}.${builtins.elemAt rubyVersionSplit 1}";

      # Framework detection
      frameworkInfo = detectFramework {src = ./.;};
      framework = frameworkInfo.framework;

      gccPackage =
        if gccVersion == "latest"
        then pkgs.gcc
        else pkgs."gcc${gccVersion}";

      opensslPackage =
        if opensslVersion == "3_2"
        then pkgs.openssl_3
        else pkgs."openssl_${opensslVersion}";

      # Bundler package with correct version from Gemfile.lock
      bundlerPackage = pkgs.stdenv.mkDerivation {
        name = "bundler-${bundlerVersion}";
        buildInputs = [rubyPackage];
        dontUnpack = true;
        installPhase = ''
          mkdir -p $out/bin
          export GEM_HOME=$out/lib/ruby/gems/${rubyMajorMinor}.0
          export PATH=$out/bin:${rubyPackage}/bin:$PATH
          ${rubyPackage}/bin/gem install bundler --version ${bundlerVersion} --no-document --bindir=$out/bin
          # Ensure both bundle and bundler commands work
          if [ ! -f $out/bin/bundler ]; then
            ln -sf $out/bin/bundle $out/bin/bundler
          fi
        '';
      };

      # Shared build inputs for all Ruby apps
      universalBuildInputs =
        [
          rubyPackage
          opensslPackage
          pkgs.libxml2
          pkgs.libxslt
          pkgs.zlib
          pkgs.libyaml
          pkgs.curl
        ]
        ++ (
          if frameworkInfo.needsPostgresql
          then [
            pkgs.libpqxx # PostgreSQL client library
            pkgs.postgresql # PostgreSQL tools
          ]
          else []
        )
        ++ (
          if frameworkInfo.needsMysql
          then [
            pkgs.libmysqlclient # MySQL client library
            pkgs.mysql80 # MySQL tools
          ]
          else []
        )
        ++ (
          if frameworkInfo.needsSqlite
          then [
            pkgs.sqlite # SQLite library
          ]
          else []
        )
        ++ (
          if frameworkInfo.hasAssets
          then [
            pkgs.nodejs # Node.js for asset compilation
          ]
          else []
        )
        ++ (
          if frameworkInfo.needsRedis
          then [
            pkgs.redis # Redis server and tools
          ]
          else []
        )
        ++ (
          if frameworkInfo.needsImageMagick
          then [
            pkgs.imagemagick # ImageMagick for image processing
          ]
          else []
        )
        ++ (
          if frameworkInfo.needsLibVips
          then [
            pkgs.vips # libvips for fast image processing
          ]
          else []
        )
        ++ (
          if frameworkInfo.needsBrowserDrivers
          then [
            pkgs.chromium # Browser for testing (headless mode)
            pkgs.chromedriver # WebDriver for Selenium
          ]
          else []
        );

      builderExtraInputs = [
        gccPackage
        pkgs.pkg-config
        pkgs.rsync
        pkgs.bundix # For generating gemset.nix
      ];

      # Shared scripts (only if gems are actually present)
      manage-postgres-script =
        if frameworkInfo.needsPostgresql
        then pkgs.writeShellScriptBin "manage-postgres" (import (ruby-builder + /imports/manage-postgres-script.nix) {inherit pkgs;})
        else null;
      manage-redis-script =
        if frameworkInfo.needsRedis
        then pkgs.writeShellScriptBin "manage-redis" (import (ruby-builder + /imports/manage-redis-script.nix) {inherit pkgs;})
        else null;
      generate-dependencies-script = pkgs.writeShellScriptBin "generate-dependencies" (import (ruby-builder + /imports/generate-dependencies.nix) {inherit pkgs bundlerVersion rubyPackage;});
      fix-gemset-sha-script = pkgs.writeShellScriptBin "fix-gemset-sha" (import (ruby-builder + /imports/fix-gemset-sha.nix) {inherit pkgs;});

      # Bundler approach (traditional) - using Rails builder with framework override
      bundlerBuild = let
        railsBuild = (import (ruby-builder + "/imports/make-rails-build.nix") {inherit pkgs;}) {
          inherit rubyVersion gccVersion opensslVersion;
          src = ./.;
          buildRailsApp = pkgs.writeShellScriptBin "make-ruby-app" (import (ruby-builder + /imports/make-generic-ruby-app-script.nix) {inherit pkgs rubyPackage bundlerVersion rubyMajorMinor framework;});
        };
        # Override the app name to be framework-specific
        frameworkApp = pkgs.stdenv.mkDerivation {
          name = "${framework}-app";
          src = railsBuild.app;
          installPhase = ''
            cp -r $src $out
          '';
        };
        # Override the docker image name
        frameworkDockerImage = railsBuild.dockerImage;
      in {
        app = frameworkApp;
        shell = railsBuild.shell;
        dockerImage = frameworkDockerImage;
      };

      # Bundix approach - disabled for now to avoid evaluation issues
      # Use bootstrap shell and manual package building after fixing hashes
      bundixBuild = null;

      # BundlerEnv approach - auto-detects gemset.nix vs lockfile-only mode
      # This provides direct gem access without bundle exec
      bundlerEnvPackage = let
        baseConfig = {
          name = "${framework}-gems";
          ruby = rubyPackage;
        };
        modeConfig =
          if builtins.pathExists ./gemset.nix
          then {
            # Use gemset.nix mode for full hash verification
            gemdir = ./.;
          }
          else {
            # Lockfile-only mode - uses Gemfile.lock without hash verification
            gemfile = ./Gemfile;
            lockfile = ./Gemfile.lock;
            gemset = pkgs.writeText "empty-gemset.nix" "{}";
          };
      in
        pkgs.bundlerEnv (baseConfig // modeConfig);

      # Shared shell hook
      defaultShellHook = ''
        export PS1="${framework}-shell:>"
        export PKG_CONFIG_PATH="${pkgs.curl.dev}/lib/pkgconfig${
          if frameworkInfo.needsPostgresql
          then ":${pkgs.postgresql}/lib/pkgconfig"
          else ""
        }${
          if frameworkInfo.needsMysql
          then ":${pkgs.mysql80}/lib/pkgconfig"
          else ""
        }"
        export LD_LIBRARY_PATH="${pkgs.curl}/lib${
          if frameworkInfo.needsPostgresql
          then ":${pkgs.postgresql}/lib"
          else ""
        }${
          if frameworkInfo.needsMysql
          then ":${pkgs.mysql80}/lib"
          else ""
        }:${opensslPackage}/lib"
        unset RUBYLIB
      '';

      packages =
        {
          ruby = rubyPackage;
          flakeVersion = pkgs.writeText "flake-version" "Flake Version: ${version}";
          generate-dependencies = generate-dependencies-script;
          fix-gemset-sha = fix-gemset-sha-script;

          # Bundler approach packages
          package-with-bundler = bundlerBuild.app;
          docker-with-bundler = bundlerBuild.dockerImage;

          # BundlerEnv approach - direct gem access
          package-with-bundlerenv = bundlerEnvPackage;
        }
        // (
          if frameworkInfo.needsPostgresql
          then
            (
              if manage-postgres-script != null
              then {manage-postgres = manage-postgres-script;}
              else {}
            )
          else {}
        )
        // (
          if frameworkInfo.needsRedis
          then
            (
              if manage-redis-script != null
              then {manage-redis = manage-redis-script;}
              else {}
            )
          else {}
        );
      # Note: bundix packages removed to prevent shell evaluation failures
      # Use `nix build .#package-with-bundix` directly after fixing gemset.nix hashes

      devShells =
        {
          # Default shell
          default = pkgs.mkShell {
            buildInputs =
              universalBuildInputs
              ++ builderExtraInputs
              ++ [bundlerPackage]
              ++ (pkgs.lib.optionals (manage-postgres-script != null) [manage-postgres-script])
              ++ (pkgs.lib.optionals (manage-redis-script != null) [manage-redis-script]);
            shellHook =
              defaultShellHook
              + ''
                export PATH=${bundlerPackage}/bin:$PATH  # Ensure correct bundler version comes first

                echo "🔧 ${framework} application detected"
                echo "   Framework: ${framework}"
                echo "   Entry point: ${frameworkInfo.entryPoint or "auto-detected"}"
                echo "   Web app: ${
                  if frameworkInfo.isWebApp
                  then "yes"
                  else "no"
                }"
                echo "   Has assets: ${
                  if frameworkInfo.hasAssets
                  then "yes (${frameworkInfo.assetPipeline or "unknown"})"
                  else "no"
                }"
                echo "   Database: ${
                  if frameworkInfo.needsPostgresql
                  then "PostgreSQL"
                  else if frameworkInfo.needsMysql
                  then "MySQL"
                  else if frameworkInfo.needsSqlite
                  then "SQLite"
                  else "none detected"
                }"
                echo "   Cache: ${
                  if frameworkInfo.needsRedis
                  then "Redis"
                  else if frameworkInfo.needsMemcached
                  then "Memcached"
                  else "none detected"
                }"
                echo "   Background jobs: ${
                  if frameworkInfo.needsBackgroundJobs
                  then "detected"
                  else "none detected"
                }"
                echo "   Image processing: ${
                  if frameworkInfo.needsImageMagick
                  then "ImageMagick"
                  else if frameworkInfo.needsLibVips
                  then "libvips"
                  else "none detected"
                }"
                echo "   Browser testing: ${
                  if frameworkInfo.needsBrowserDrivers
                  then "enabled"
                  else "none detected"
                }"
                echo "   Bundler version: ${bundlerVersion} (matches Gemfile.lock)"
              '';
          };

          # BundlerEnv approach - direct gem access
          with-bundlerenv = pkgs.mkShell {
            buildInputs =
              universalBuildInputs
              ++ builderExtraInputs
              ++ [
                bundlerEnvPackage
              ]
              ++ (pkgs.lib.optionals (manage-postgres-script != null) [manage-postgres-script])
              ++ (pkgs.lib.optionals (manage-redis-script != null) [manage-redis-script]);

            shellHook =
              defaultShellHook
              + ''
                export APP_ROOT=$(pwd)
                export PS1="$(pwd) bundlerenv-shell >"

                # Add gem executables to PATH - bundlerEnv provides direct access
                export PATH=${bundlerEnvPackage}/bin:$PATH

                # BundlerEnv environment
                export GEM_HOME=${bundlerEnvPackage}
                export BUNDLE_GEMFILE=${bundlerEnvPackage}/Gemfile

                echo "🔧 BundlerEnv Environment for ${framework} (Direct gem access)"
                echo "   Framework: ${framework} (auto-detected)"
                echo "   Ruby: ${rubyPackage.version}"
                if [ -f ./gemset.nix ]; then
                  echo "   Mode: gemset.nix + Gemfile.lock"
                else
                  echo "   Mode: Gemfile.lock only"
                fi
                echo "   Gem executables: Available directly (no bundle exec needed)"
                echo ""
                echo "🎯 Ready to use:"
                ${
                  if framework == "rails"
                  then ''
                    echo "   rails s         - Start Rails server"
                    echo "   rails c         - Rails console"
                    echo "   rails generate  - Generate Rails files"
                  ''
                  else if framework == "hanami"
                  then ''
                    echo "   hanami server   - Start Hanami server"
                    echo "   hanami console  - Hanami console"
                  ''
                  else if frameworkInfo.isWebApp
                  then ''
                    echo "   rackup          - Start web server"
                  ''
                  else ''
                    echo "   rake            - Run rake tasks"
                  ''
                }
                echo "   bundix          - Generate gemset.nix (optional, for reproducibility)"
                echo ""
                echo "💎 Direct Gem Access: All gem executables available without bundle exec"
              '';
          };

          # Traditional bundler approach
          with-bundler = pkgs.mkShell {
            buildInputs =
              universalBuildInputs
              ++ builderExtraInputs
              ++ [bundlerPackage]
              ++ (pkgs.lib.optionals (manage-postgres-script != null) [manage-postgres-script])
              ++ (pkgs.lib.optionals (manage-redis-script != null) [manage-redis-script]);
            shellHook =
              defaultShellHook
              + ''
                export PS1="$(pwd) bundler-shell >"
                export APP_ROOT=$(pwd)

                # Bundle isolation - same as build scripts
                export BUNDLE_PATH=$APP_ROOT/vendor/bundle
                export BUNDLE_GEMFILE=$PWD/Gemfile
                export PATH=$BUNDLE_PATH/bin:$APP_ROOT/bin:${bundlerPackage}/bin:${rubyPackage}/bin:$PATH

                echo "🔧 Traditional bundler environment for ${framework}:"
                echo "   bundle install  - Install gems to ./vendor/bundle"
                echo "   bundle exec     - Run commands with bundler"
                ${
                  if frameworkInfo.isWebApp
                  then ''
                    echo "   Start server:   - bundle exec ${
                      if framework == "rails"
                      then "rails s"
                      else if framework == "hanami"
                      then "hanami server"
                      else "rackup"
                    }"
                  ''
                  else ''
                    echo "   Run app:        - bundle exec ruby your_script.rb"
                  ''
                }
                echo "   Gems isolated in: ./vendor/bundle"
                echo "   Bundler version: ${bundlerVersion} (matches Gemfile.lock)"
              '';
          };
        }
        // {
          # Bundix approach shell - always starts in bootstrap mode first
          with-bundix = pkgs.mkShell {
            # Minimal bootstrap environment - no complex dependencies
            buildInputs = [
              rubyPackage
              bundlerPackage
              pkgs.bundix
              pkgs.git
              pkgs.rsync
              # Core build dependencies only - minimal set
              gccPackage
              pkgs.pkg-config
              opensslPackage
              pkgs.libxml2
              pkgs.libxslt
              pkgs.zlib
              pkgs.libyaml
              # Add PostgreSQL only if needed (for pg gem compilation)
              pkgs.postgresql
              pkgs.postgresql.dev
            ];

            shellHook =
              defaultShellHook
              + ''
                export APP_ROOT=$(pwd)
                export PS1="$(pwd) bundix-bootstrap >"

                # Always start in bootstrap mode - this guarantees shell startup success
                export PATH=${bundlerPackage}/bin:${rubyPackage}/bin:${pkgs.bundix}/bin:$PATH
                export BUNDLE_FORCE_RUBY_PLATFORM=true  # Generate ruby platform gems, not native

                # Bootstrap Ruby environment - same as bundlerEnv for consistency
                export RUBYLIB=${rubyPackage}/lib/ruby/site_ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/site_ruby/${rubyMajorMinor}.0
                export RUBYOPT=-I${rubyPackage}/lib/ruby/site_ruby/${rubyMajorMinor}.0
                export GEM_HOME=${rubyPackage}/lib/ruby/gems/${rubyMajorMinor}.0
                export GEM_PATH=${rubyPackage}/lib/ruby/gems/${rubyMajorMinor}.0

                # Unset conflicting bundle environment
                unset BUNDLE_PATH BUNDLE_GEMFILE

                # Environment variables for gem compilation (same as bundlerEnv)
                export PKG_CONFIG_PATH="${opensslPackage}/lib/pkgconfig:${pkgs.libxml2.dev}/lib/pkgconfig:${pkgs.libxslt.dev}/lib/pkgconfig:${pkgs.zlib.dev}/lib/pkgconfig${
                  if frameworkInfo.needsPostgresql
                  then ":${pkgs.postgresql.dev}/lib/pkgconfig"
                  else ""
                }"

                echo "🔧 Bundix Environment for ${framework} (Bootstrap Mode)"
                echo "   Ruby: ${rubyPackage.version}"
                echo "   Bundler: ${bundlerVersion} (matches Gemfile.lock)"
                echo "   Framework: ${framework} (auto-detected)"
                echo ""

                # Check if we can upgrade to normal mode (gemset.nix works)
                if [ -f ./gemset.nix ]; then
                  echo "📦 Testing if gemset.nix works with bundlerEnv..."
                  echo "   Running: nix build .#package-with-bundix --no-link"
                  echo ""

                  # Test bundlerEnv in the background and show result
                  if timeout 10 nix build .#package-with-bundix --no-link >/dev/null 2>&1; then
                    echo "✅ SUCCESS: gemset.nix works! You can upgrade to normal mode:"
                    echo "   exit                    - Exit this shell"
                    echo "   nix develop .#with-bundix-normal  - Use bundlerEnv (no bundle exec needed)"
                    echo ""
                    echo "   Or continue in bootstrap mode below ⬇️"
                  else
                    echo "❌ FAILED: gemset.nix has hash mismatches (expected with nokogiri)"
                    echo "   This is normal for fresh projects or after gem updates"
                  fi
                  echo ""
                else
                  echo "📦 No gemset.nix found - this is expected for new projects"
                  echo ""
                fi

                echo "🔧 Fix gemset.nix workflow:"
                echo "   bundix          - Regenerate gemset.nix from Gemfile.lock"
                echo "   exit            - Exit this shell"
                echo "   nix develop .#with-bundix  - Re-enter (will test new gemset.nix)"
                echo ""
                echo "📦 Dependency Management:"
                echo "   bundle lock     - Update Gemfile.lock"
                echo "   bundle add gem  - Add new gem to Gemfile"
                echo "   bundix          - Regenerate gemset.nix from Gemfile.lock"
                echo ""
                ${
                  if frameworkInfo.needsPostgresql || frameworkInfo.needsRedis
                  then ''
                    echo "🗄️ Database & Services:"
                    ${
                      if frameworkInfo.needsPostgresql
                      then ''
                        echo "   manage-postgres start - Start PostgreSQL server"
                        echo "   manage-postgres help  - Show PostgreSQL connection info"
                      ''
                      else ""
                    }
                    ${
                      if frameworkInfo.needsRedis
                      then ''
                        echo "   manage-redis start    - Start Redis server"
                      ''
                      else ""
                    }
                    echo ""
                  ''
                  else ""
                }
                echo "💎 Bootstrap Environment: Ruby with bundix (same build deps as bundlerEnv)"
              '';
          };

          # Note: with-bundix-normal shell removed for now to avoid bundlerEnv evaluation issues
          # Users should use `with-bundix` (bootstrap) and manually build packages after fixing hashes
        };

      apps = {
        detectFramework = {
          type = "app";
          program = "${pkgs.writeShellScriptBin "detectFramework" ''
            echo "Framework: ${framework}"
            echo "Is web app: ${
              if frameworkInfo.isWebApp
              then "yes"
              else "no"
            }"
            echo "Has assets: ${
              if frameworkInfo.hasAssets
              then "yes (${frameworkInfo.assetPipeline or "unknown"})"
              else "no"
            }"
            echo "Entry point: ${frameworkInfo.entryPoint or "auto-detected"}"
            echo "Database gems detected:"
            echo "  PostgreSQL (pg): ${
              if frameworkInfo.needsPostgresql
              then "yes"
              else "no"
            }"
            echo "  MySQL (mysql2): ${
              if frameworkInfo.needsMysql
              then "yes"
              else "no"
            }"
            echo "  SQLite (sqlite3): ${
              if frameworkInfo.needsSqlite
              then "yes"
              else "no"
            }"
            echo "Cache gems detected:"
            echo "  Redis: ${
              if frameworkInfo.needsRedis
              then "yes"
              else "no"
            }"
            echo "  Memcached: ${
              if frameworkInfo.needsMemcached
              then "yes"
              else "no"
            }"
            echo "Background job gems detected:"
            echo "  Background jobs: ${
              if frameworkInfo.needsBackgroundJobs
              then "yes"
              else "no"
            }"
            echo "Image processing gems detected:"
            echo "  ImageMagick: ${
              if frameworkInfo.needsImageMagick
              then "yes"
              else "no"
            }"
            echo "  libvips: ${
              if frameworkInfo.needsLibVips
              then "yes"
              else "no"
            }"
            echo "Browser testing gems detected:"
            echo "  Browser drivers: ${
              if frameworkInfo.needsBrowserDrivers
              then "yes"
              else "no"
            }"
          ''}/bin/detectFramework";
        };
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
    in {
      inherit apps packages devShells;
    };
  in {
    apps = forAllSystems (system: (mkOutputsForSystem system).apps);
    packages = forAllSystems (system: (mkOutputsForSystem system).packages);
    devShells = forAllSystems (system: (mkOutputsForSystem system).devShells);
  };
}
