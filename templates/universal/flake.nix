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
        # OpenSSL 1.1.1w is permitted as a fallback for older Ruby versions,
        # legacy gems with native extensions, or transitive dependencies that
        # haven't been updated for OpenSSL 3.x. The build uses opensslVersion
        # (below) by default, but this prevents Nix from failing when a
        # dependency pulls in the older version.
        config.permittedInsecurePackages = ["openssl-1.1.1w"];
      };

    version = "3.2.0";
    gccVersion = "latest";
    # Default OpenSSL version for builds. Change to "1_1" if you encounter
    # compatibility issues with older gems or Ruby versions.
    opensslVersion = "3_2";

    # Import framework detection
    detectFramework = import (ruby-builder + "/imports/detect-framework.nix");

    # Import version detection functions
    versionDetection = import (ruby-builder + "/imports/detect-versions.nix");
    detectRubyVersion = versionDetection.detectRubyVersion;
    detectBundlerVersion = versionDetection.detectBundlerVersion;
    detectNodeVersion = versionDetection.detectNodeVersion;

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

      # Bundler package with exact version from Gemfile.lock
      # Uses precomputed hashes from bundler-hashes.nix for reproducible builds
      bundlerHashes = import (ruby-builder + "/bundler-hashes.nix");
      bundlerPackage = let
        hashInfo = bundlerHashes.${bundlerVersion} or null;
      in
        if hashInfo != null
        then
          pkgs.buildRubyGem {
            inherit (hashInfo) sha256;
            ruby = rubyPackage;
            gemName = "bundler";
            version = bundlerVersion;
            source.sha256 = hashInfo.sha256;
          }
        else
          # Fallback to nixpkgs bundler if version not in hashes
          pkgs.bundler.override { ruby = rubyPackage; };

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
          # Browser drivers only on Linux - Darwin doesn't support driverLink
          if frameworkInfo.needsBrowserDrivers && pkgs.stdenv.isLinux
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
          buildRailsApp = pkgs.writeShellScriptBin "make-ruby-app" (import (ruby-builder + /imports/make-generic-ruby-app-script.nix) {inherit pkgs rubyPackage bundlerPackage bundlerVersion rubyMajorMinor framework;});
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
      # Bundix approach (Nix bundlerEnv) - only if gemset.nix exists
      bundixBuild =
        if builtins.pathExists ./gemset.nix
        then let
          # Simple bundlerEnv without auto-fix for package builds
          gems = pkgs.bundlerEnv {
            name = "${framework}-gems";
            ruby = rubyPackage;
            gemdir = ./.;
            gemset = ./gemset.nix;
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

          bundixShellHook = ''
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
          '';
        in
          # Use Rails build script for all frameworks - it's generic enough
          import (ruby-builder + "/imports/make-rails-nix-build.nix") {
            inherit pkgs rubyVersion gccVersion opensslVersion universalBuildInputs rubyPackage rubyMajorMinor gems gccPackage opensslPackage usrBinDerivation tzinfo;
            src = ./.;
            defaultShellHook = bundixShellHook;
            nodeModules = pkgs.runCommand "empty-node-modules" {} "mkdir -p $out/lib/node_modules";
            yarnOfflineCache = pkgs.runCommand "empty-yarn-cache" {} "mkdir -p $out";
            buildRailsApp =
              if framework == "rails" then
                pkgs.writeShellScriptBin "make-rails-app-with-nix" (import (ruby-builder + /imports/make-rails-app-script.nix) {inherit pkgs rubyPackage bundlerVersion rubyMajorMinor;})
              else if frameworkInfo.hasRakefile then
                pkgs.writeShellScriptBin "make-${framework}-app-with-nix" ''
                  echo "Building ${framework} application..."
                  rake build 2>/dev/null || echo "No build task found, continuing..."
                ''
              else
                pkgs.writeShellScriptBin "make-${framework}-app-with-nix" ''
                  echo "Building ${framework} application..."
                  echo "No specific build process for ${framework}"
                '';
          }
        else null;

      # BundlerEnv approach - auto-detects gemset.nix vs lockfile-only mode
      # This provides direct gem access without bundle exec
      bundlerEnvPackage = let
        baseConfig = {
          name = "${framework}-gems";
          ruby = rubyPackage;
        };
        modeConfig =
          if builtins.pathExists ./gemset.nix
          then {gemset = ./gemset.nix;}
          else {
            # Lockfile-only mode - uses Gemfile.lock without hash verification
            gemfile = ./Gemfile;
            lockfile = ./Gemfile.lock;
            gemdir = ./.;
            gemset = pkgs.writeText "empty-gemset.nix" "{ }";
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
          if bundixBuild != null then {
            # Bundix approach packages - direct gem access
            package-with-bundix = bundixBuild.app;
            docker-with-bundix = bundixBuild.dockerImage;
          } else {}
        )
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
                export APP_ROOT=$(pwd)

                # Complete Ruby environment isolation - prevent external Ruby artifacts
                # This prevents loading gems compiled for different Ruby versions (e.g., ~/.gem)
                unset GEM_HOME
                unset GEM_PATH
                unset GEM_SPEC_CACHE
                unset RUBYOPT
                unset RUBYLIB

                # Bundle isolation - gems go to project-local vendor/bundle
                export BUNDLE_PATH=$APP_ROOT/vendor/bundle
                export BUNDLE_GEMFILE=$APP_ROOT/Gemfile
                export BUNDLE_APP_CONFIG=$APP_ROOT/.bundle

                # Set GEM paths to project-local only - no system gems or ~/.gem
                # Include Ruby's built-in gems from the Nix store to avoid loading from ~/.gem
                export GEM_HOME=$APP_ROOT/vendor/bundle/ruby/${rubyMajorMinor}.0
                export GEM_PATH=$APP_ROOT/vendor/bundle/ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/gems/${rubyMajorMinor}.0
                export GEM_SPEC_CACHE=$APP_ROOT/tmp/gem_spec_cache

                # PATH: Project bins first, then Nix-provided Ruby/Bundler only
                # Include essential shell tools but exclude inherited PATH to prevent Ruby version conflicts
                export PATH=$APP_ROOT/vendor/bundle/ruby/${rubyMajorMinor}.0/bin:$APP_ROOT/bin:${bundlerPackage}/bin:${rubyPackage}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.gnused}/bin:${pkgs.gnugrep}/bin:${pkgs.findutils}/bin:${pkgs.gawk}/bin:${pkgs.git}/bin:${pkgs.which}/bin:${pkgs.less}/bin

                echo "🔧 ${framework} application detected (Nix-isolated environment)"
                echo "   Ruby: ${rubyVersion}"
                echo "   Bundler: ${bundlerVersion} (matches Gemfile.lock)"
                echo "   Framework: ${framework}"
                echo "   Entry point: ${if frameworkInfo.entryPoint != null then frameworkInfo.entryPoint else "auto-detected"}"
                echo "   Web app: ${
                  if frameworkInfo.isWebApp
                  then "yes"
                  else "no"
                }"
                echo "   Has assets: ${
                  if frameworkInfo.hasAssets
                  then "yes (${if frameworkInfo.assetPipeline != null then frameworkInfo.assetPipeline else "unknown"})"
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

                # Complete Ruby environment isolation - prevent external Ruby artifacts
                unset GEM_HOME
                unset GEM_PATH
                unset RUBYOPT
                unset RUBYLIB

                # BundlerEnv environment - gems from Nix store
                export GEM_HOME=${bundlerEnvPackage}
                export GEM_PATH=${bundlerEnvPackage}
                export BUNDLE_GEMFILE=$APP_ROOT/Gemfile

                # PATH: BundlerEnv bins first, then Nix-provided Ruby only
                # Include essential shell tools but exclude inherited PATH to prevent Ruby version conflicts
                export PATH=${bundlerEnvPackage}/bin:${rubyPackage}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.gnused}/bin:${pkgs.gnugrep}/bin:${pkgs.findutils}/bin:${pkgs.gawk}/bin:${pkgs.git}/bin:${pkgs.which}/bin:${pkgs.less}/bin

                echo "🔧 BundlerEnv Environment for ${framework} (Nix-isolated, direct gem access)"
                echo "   Ruby: ${rubyVersion}"
                echo "   Framework: ${framework} (auto-detected)"
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

                # Complete Ruby environment isolation - prevent external Ruby artifacts
                # This prevents loading gems compiled for different Ruby versions (e.g., ~/.gem)
                unset GEM_HOME
                unset GEM_PATH
                unset GEM_SPEC_CACHE
                unset RUBYOPT
                unset RUBYLIB

                # Bundle isolation - gems go to project-local vendor/bundle
                export BUNDLE_PATH=$APP_ROOT/vendor/bundle
                export BUNDLE_GEMFILE=$APP_ROOT/Gemfile
                export BUNDLE_APP_CONFIG=$APP_ROOT/.bundle

                # Set GEM paths to project-local only - no system gems or ~/.gem
                # Include Ruby's built-in gems from the Nix store to avoid loading from ~/.gem
                export GEM_HOME=$APP_ROOT/vendor/bundle/ruby/${rubyMajorMinor}.0
                export GEM_PATH=$APP_ROOT/vendor/bundle/ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/gems/${rubyMajorMinor}.0
                export GEM_SPEC_CACHE=$APP_ROOT/tmp/gem_spec_cache

                # PATH: Project bins first, then Nix-provided Ruby/Bundler only
                # Include essential shell tools but exclude inherited PATH to prevent Ruby version conflicts
                export PATH=$APP_ROOT/vendor/bundle/ruby/${rubyMajorMinor}.0/bin:$APP_ROOT/bin:${bundlerPackage}/bin:${rubyPackage}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.gnused}/bin:${pkgs.gnugrep}/bin:${pkgs.findutils}/bin:${pkgs.gawk}/bin:${pkgs.git}/bin:${pkgs.which}/bin:${pkgs.less}/bin

                echo "🔧 Traditional bundler environment for ${framework}:"
                echo "   Ruby: ${rubyVersion} (Nix-isolated)"
                echo "   Bundler: ${bundlerVersion} (matches Gemfile.lock)"
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
              '';
          };
        }
        // {
          # Bundix approach shell - always starts in bootstrap mode first
          with-bundix-bootstrap = pkgs.mkShell {
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
                # PATH priority: 1) Local gem bins, 2) Bundler derivation, 3) Ruby, 4) Bundix, 5) System
                export PATH="$APP_ROOT/vendor/bundle/ruby/${rubyMajorMinor}.0/bin:${bundlerPackage}/bin:${rubyPackage}/bin:${pkgs.bundix}/bin:$PATH"
                export BUNDLE_FORCE_RUBY_PLATFORM=true  # Generate ruby platform gems, not native

                # Bootstrap Ruby environment - prioritize local bundle over system
                # Don't mix system Ruby libraries with bundled gems to avoid conflicts
                export GEM_HOME="$APP_ROOT/vendor/bundle/ruby/${rubyMajorMinor}.0"
                export GEM_PATH="$APP_ROOT/vendor/bundle/ruby/${rubyMajorMinor}.0"

                # Allow bundler to manage local gems in vendor/bundle
                export BUNDLE_APP_CONFIG="$APP_ROOT/.bundle"
                export BUNDLE_PATH="$APP_ROOT/vendor/bundle"

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
                    echo "   nix develop .#with-bundix  - Use bundlerEnv (no bundle exec needed)"
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
                echo "   nix develop .#with-bundix-bootstrap  - Re-enter (will test new gemset.nix)"
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

          # Normal bundix shell using bundlerEnv - direct gem access
          with-bundix =
            if builtins.pathExists ./gemset.nix then
              let
                # Simple bundlerEnv without auto-fix for devshell
                shellGems = pkgs.bundlerEnv {
                  name = "${framework}-gems";
                  ruby = rubyPackage;
                  gemdir = ./.;
                  gemset = ./gemset.nix;
                };
              in pkgs.mkShell {
                buildInputs = [ rubyPackage pkgs.bundix ];
                shellHook = defaultShellHook + ''
                  # Complete Ruby environment isolation - prevent external Ruby artifacts
                  unset GEM_HOME
                  unset GEM_PATH
                  unset RUBYOPT
                  unset RUBYLIB

                  # Set up bundlerEnv environment - gems from Nix store only
                  export GEM_HOME=${shellGems}/lib/ruby/gems/${rubyMajorMinor}.0
                  export GEM_PATH=${shellGems}/lib/ruby/gems/${rubyMajorMinor}.0

                  # PATH: Nix-provided gems and Ruby only - no inherited PATH
                  # Include essential shell tools but exclude inherited PATH to prevent Ruby version conflicts
                  export PATH=${shellGems}/bin:${rubyPackage}/bin:${pkgs.bundix}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.gnused}/bin:${pkgs.gnugrep}/bin:${pkgs.findutils}/bin:${pkgs.gawk}/bin:${pkgs.git}/bin:${pkgs.which}/bin:${pkgs.less}/bin

                  echo "💎 Bundix Environment: Direct gem access (Nix-isolated)"
                  echo "   Ruby: ${rubyVersion}"
                  echo "   Framework: ${framework} (auto-detected)"
                  echo "   GEM_HOME: $GEM_HOME"
                '';
              }
            else
              pkgs.mkShell {
                buildInputs = [ rubyPackage pkgs.bundix ];
                shellHook = ''
                  echo "❌ gemset.nix not available or has issues"
                  echo "   Use: nix develop .#with-bundix-bootstrap (bootstrap mode)"
                '';
              };
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
