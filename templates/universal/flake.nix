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

    # Version inherited from rails-builder (single source of truth)
    version = ruby-builder.version or "unknown";
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
    detectTailwindVersion = versionDetection.detectTailwindVersion;

    # Import tailwindcss hashes for exact version matching
    tailwindcssHashes = import (ruby-builder + "/tailwindcss-hashes.nix");

    # Application name for Nix store paths and Docker images
    # This name is used for:
    #   - Nix derivation name (appears in /nix/store/<hash>-<appName>)
    #   - Docker image name (e.g., <appName>-image:latest)
    # Defaults to the directory name. Customize for multi-app repos or clarity:
    #   appName = "my-rails-app";
    #   appName = "ops-core-api";
    appName = builtins.baseNameOf (builtins.toString ./.);

    mkOutputsForSystem = system: let
      pkgs = mkPkgsForSystem system;
      # Use custom bundix from ruby-builder (glenndavy/bundix fork with fixes)
      customBundix = ruby-builder.packages.${system}.bundix;
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
      bundlerPackageBase = let
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
          pkgs.bundler.override {ruby = rubyPackage;};

      # Wrapper that provides both 'bundle' and 'bundler' commands
      # buildRubyGem only creates 'bundler', but we need 'bundle' too
      bundlerPackage = pkgs.symlinkJoin {
        name = "bundler-${bundlerVersion}-wrapped";
        paths = [ bundlerPackageBase ];
        postBuild = ''
          # Create 'bundle' symlink to 'bundler' if it doesn't exist
          if [ -f $out/bin/bundler ] && [ ! -f $out/bin/bundle ]; then
            ln -s bundler $out/bin/bundle
          fi
        '';
      };

      # Tailwindcss package - exact version from Gemfile.lock
      # This is needed because bundlerEnv uses generic ruby platform gem
      # which doesn't include the platform-specific binary
      tailwindVersion = detectTailwindVersion {src = ./.;};
      tailwindcssPackage =
        if tailwindVersion != null && frameworkInfo.needsTailwindcss
        then
          import (ruby-builder + "/imports/make-tailwindcss.nix") {
            inherit pkgs tailwindcssHashes;
            version = tailwindVersion;
          }
        else null;

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
          pkgs.pkg-config
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
        )
        ++ (
          # Tailwindcss CLI - exact version from Gemfile.lock
          # Needed because bundlerEnv uses generic ruby platform gem
          # which doesn't include the platform-specific binary
          if tailwindcssPackage != null
          then [
            tailwindcssPackage # Tailwind CSS CLI (version-matched to gem)
          ]
          else []
        )
        ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
          pkgs.nix-ld  # For running unpatched binaries (Linux only)
          pkgs.stdenv.cc.cc.lib  # Provides dynamic linker libraries for nix-ld
        ];

      builderExtraInputs = [
        gccPackage
        pkgs.pkg-config
        pkgs.rsync
        customBundix # For generating gemset.nix (glenndavy/bundix fork)
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
      generate-dependencies-script = pkgs.writeShellScriptBin "generate-dependencies" (import (ruby-builder + /imports/generate-dependencies.nix) {
        inherit pkgs bundlerVersion rubyPackage;
        bundixPackage = customBundix;
      });
      fix-gemset-sha-script = pkgs.writeShellScriptBin "fix-gemset-sha" (import (ruby-builder + /imports/fix-gemset-sha.nix) {inherit pkgs;});

      # Bundler approach (traditional) - using Rails builder with framework override
      bundlerBuild = let
        railsBuild = (import (ruby-builder + "/imports/make-rails-build.nix") {inherit pkgs;}) {
          inherit rubyVersion gccVersion opensslVersion appName bundlerPackage;
          railsBuilderVersion = version;
          # Use rev if clean, dirtyRev if dirty (strip "-dirty" suffix)
          appRevision = let
            rev = self.rev or self.dirtyRev or null;
          in if rev != null then builtins.replaceStrings ["-dirty"] [""] rev else null;
          railsEnv = "production";
          src = ./.;
          buildRailsApp = pkgs.writeShellScriptBin "make-ruby-app" (import (ruby-builder + /imports/make-generic-ruby-app-script.nix) {inherit pkgs rubyPackage bundlerPackage bundlerVersion rubyMajorMinor framework;});
        };
        # Override the app name to include framework if desired
        # By default uses appName from parent scope (directory name)
        frameworkApp = pkgs.stdenv.mkDerivation {
          name = appName;  # Use consistent app name
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
      # Use custom bundlerEnv from ruby-builder that handles path gems correctly
      customBundlerEnv = ruby-builder.lib.${system}.customBundlerEnv;

      bundixBuild =
        if builtins.pathExists ./gemset.nix
        then let
          # Use custom bundlerEnv that handles vendor/cache path gems
          gems = customBundlerEnv {
            name = "${framework}-gems";
            ruby = rubyPackage;
            gemdir = ./.;
            gemset = ./gemset.nix;
            gemConfig = pkgs.defaultGemConfig // {
              ruby-vips = attrs: {
                buildInputs = [ pkgs.vips ];
              };
            };
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
            echo "Bundix Shell Hook"
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
            export DATABASE_URL="postgresql://localhost/dummy_build_db"
          '';
        in
          # Use Rails build script for all frameworks - it's generic enough
          import (ruby-builder + "/imports/make-rails-nix-build.nix") {
            inherit pkgs rubyVersion gccVersion opensslVersion universalBuildInputs rubyPackage rubyMajorMinor gems gccPackage opensslPackage usrBinDerivation tzinfo tailwindcssPackage bundlerPackage appName;
            railsBuilderVersion = version;
            # Use rev if clean, dirtyRev if dirty (strip "-dirty" suffix)
            appRevision = let
              rev = self.rev or self.dirtyRev or null;
            in if rev != null then builtins.replaceStrings ["-dirty"] [""] rev else null;
            src = ./.;
            defaultShellHook = bundixShellHook;
            nodeModules = pkgs.runCommand "empty-node-modules" {} "mkdir -p $out/lib/node_modules";
            yarnOfflineCache = pkgs.runCommand "empty-yarn-cache" {} "mkdir -p $out";
            buildRailsApp =
              if framework == "rails"
              then pkgs.writeShellScriptBin "make-rails-app-with-nix" (import (ruby-builder + /imports/make-rails-app-script.nix) {inherit pkgs rubyPackage bundlerVersion rubyMajorMinor;})
              else if frameworkInfo.hasRakefile
              then
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
          then {
            gemset = ./gemset.nix;
            gemConfig = pkgs.defaultGemConfig // {
              ruby-vips = attrs: {
                buildInputs = [ pkgs.vips ];
              };
            };
          }
          else {
            # Lockfile-only mode - uses Gemfile.lock without hash verification
            gemfile = ./Gemfile;
            lockfile = ./Gemfile.lock;
            gemdir = ./.;
            gemset = pkgs.writeText "empty-gemset.nix" "{ }";
            gemConfig = pkgs.defaultGemConfig // {
              ruby-vips = attrs: {
                buildInputs = [ pkgs.vips ];
              };
            };
          };
      in
        pkgs.bundlerEnv (baseConfig // modeConfig);

      # Shared shell hook
      defaultShellHook = ''
        # Save original PATH at the very start (includes buildInputs from Nix)
        # This preserves access to gcc, make, pkg-config, etc. plus system tools
        ORIGINAL_PATH="$PATH"

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
        export DATABASE_URL="postgresql://localhost/dummy_build_db"

        # Configure nix-ld for running unpatched binaries (Linux only)
        ${pkgs.lib.optionalString pkgs.stdenv.isLinux ''
          export NIX_LD="${pkgs.stdenv.cc.bintools.dynamicLinker}"
          export NIX_LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}"
        ''}

        ${
          if tailwindcssPackage != null
          then ''
            # Point tailwindcss-ruby gem to Nix-provided binary (version ${tailwindVersion})
            export TAILWINDCSS_INSTALL_DIR="${tailwindcssPackage}/bin"
          ''
          else ""
        }
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
          # Export gems derivation separately for pre-caching
          # Build this first and push to S3 cache, then app builds won't need network access
          if bundixBuild != null
          then {
            gems-with-bundix = customBundlerEnv {
              name = "${framework}-gems";
              ruby = rubyPackage;
              gemdir = ./.;
              gemset = ./gemset.nix;
              gemConfig = pkgs.defaultGemConfig // {
                ruby-vips = attrs: {
                  buildInputs = [ pkgs.vips ];
                };
              };
            };
          }
          else {}
        )
        // (
          if bundixBuild != null
          then {
            # Bundix approach packages - direct gem access
            package-with-bundix = bundixBuild.app;
            docker-with-bundix = bundixBuild.dockerImage;
          }
          else {}
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

                # PATH: Nix Ruby/Bundler first (for isolation), then original PATH (for system tools)
                # bundlerPackage must come BEFORE app bin/ to override any old binstubs
                export PATH=$APP_ROOT/vendor/bundle/ruby/${rubyMajorMinor}.0/bin:${bundlerPackage}/bin:$APP_ROOT/bin:${rubyPackage}/bin${
                  if manage-postgres-script != null
                  then ":${manage-postgres-script}/bin"
                  else ""
                }${
                  if manage-redis-script != null
                  then ":${manage-redis-script}/bin"
                  else ""
                }:$ORIGINAL_PATH

                echo "🔧 ${framework} application detected (Nix-isolated environment)"
                echo "   Ruby: ${rubyVersion}"
                echo "   Bundler: ${bundlerVersion} (matches Gemfile.lock)"
                echo "   Framework: ${framework}"
                echo "   Entry point: ${
                  if frameworkInfo.entryPoint != null
                  then frameworkInfo.entryPoint
                  else "auto-detected"
                }"
                echo "   Web app: ${
                  if frameworkInfo.isWebApp
                  then "yes"
                  else "no"
                }"
                echo "   Has assets: ${
                  if frameworkInfo.hasAssets
                  then "yes (${
                    if frameworkInfo.assetPipeline != null
                    then frameworkInfo.assetPipeline
                    else "unknown"
                  })"
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

                # PATH: BundlerEnv/Ruby first (for isolation), then original PATH (for system tools)
                # This ensures our Ruby takes precedence but neovim, nix-shell, etc. remain accessible
                export PATH=${bundlerEnvPackage}/bin:${rubyPackage}/bin${
                  if manage-postgres-script != null
                  then ":${manage-postgres-script}/bin"
                  else ""
                }${
                  if manage-redis-script != null
                  then ":${manage-redis-script}/bin"
                  else ""
                }:$ORIGINAL_PATH

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

                # PATH: Nix Ruby/Bundler first (for isolation), then original PATH (for system tools)
                # bundlerPackage must come BEFORE app bin/ to override any old binstubs
                export PATH=$APP_ROOT/vendor/bundle/ruby/${rubyMajorMinor}.0/bin:${bundlerPackage}/bin:$APP_ROOT/bin:${rubyPackage}/bin${
                  if manage-postgres-script != null
                  then ":${manage-postgres-script}/bin"
                  else ""
                }${
                  if manage-redis-script != null
                  then ":${manage-redis-script}/bin"
                  else ""
                }:$ORIGINAL_PATH

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
              customBundix # glenndavy/bundix fork with fixes
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
                export PATH="$APP_ROOT/vendor/bundle/ruby/${rubyMajorMinor}.0/bin:${bundlerPackage}/bin:${rubyPackage}/bin:${customBundix}/bin:$PATH"
                # Note: We do NOT set BUNDLE_FORCE_RUBY_PLATFORM=true
                # This allows bundix to select platform-specific gems (e.g., tailwindcss-ruby-arm64-darwin)
                # which include pre-compiled binaries needed at runtime.
                # Use fix-gemset-sha if you encounter SHA mismatches after running bundix.

                # Bootstrap Ruby environment - prioritize local bundle over system
                # Don't mix system Ruby libraries with bundled gems to avoid conflicts
                export GEM_HOME="$APP_ROOT/vendor/bundle/ruby/${rubyMajorMinor}.0"
                export GEM_PATH="$APP_ROOT/vendor/bundle/ruby/${rubyMajorMinor}.0"

                # Allow bundler to manage local gems in vendor/bundle
                export BUNDLE_APP_CONFIG="$APP_ROOT/.bundle"
                export BUNDLE_PATH="$APP_ROOT/vendor/bundle"

                # Configure bundler for offline/cached git gems
                export BUNDLE_DISABLE_LOCAL_BRANCH_CHECK=true
                export BUNDLE_DISABLE_LOCAL_REVISION_CHECK=true
                export BUNDLE_ALLOW_OFFLINE_INSTALL=true

                # Set up local overrides for git gems in vendor/cache
                # This prevents bundler from trying to fetch from git remotes
                if [ -d "$APP_ROOT/vendor/cache" ]; then
                  for cached_gem in "$APP_ROOT/vendor/cache"/*-*; do
                    if [ -d "$cached_gem" ] && [ -f "$cached_gem/.bundlecache" ]; then
                      gem_basename=$(basename "$cached_gem")

                      # Initialize git repo if not present (needed for BUNDLE_LOCAL__ override)
                      if [ ! -d "$cached_gem/.git" ]; then
                        echo "  Initializing git repo in $gem_basename for bundler local override..."

                        # Extract branch name from Gemfile.lock for this gem
                        gem_remote_pattern=$(echo "$gem_basename" | sed 's/-[a-f0-9]\{7,\}$//')
                        branch_name=$(${pkgs.gawk}/bin/awk '
                          /^GIT/ { in_git=1; branch=""; next }
                          /^[A-Z]/ && !/^GIT/ { in_git=0 }
                          in_git && /remote:.*'"$gem_remote_pattern"'/ { found=1 }
                          in_git && found && /branch:/ { gsub(/.*branch: */, ""); print; exit }
                        ' "$APP_ROOT/Gemfile.lock" 2>/dev/null)

                        # Also extract the revision from Gemfile.lock
                        revision=$(${pkgs.gawk}/bin/awk '
                          /^GIT/ { in_git=1; next }
                          /^[A-Z]/ && !/^GIT/ { in_git=0 }
                          in_git && /remote:.*'"$gem_remote_pattern"'/ { found=1 }
                          in_git && found && /revision:/ { gsub(/.*revision: */, ""); print; exit }
                        ' "$APP_ROOT/Gemfile.lock" 2>/dev/null)

                        (
                          cd "$cached_gem"
                          ${pkgs.git}/bin/git init -q 2>/dev/null || true
                          ${pkgs.git}/bin/git config user.email "nix-build@localhost" 2>/dev/null || true
                          ${pkgs.git}/bin/git config user.name "Nix Build" 2>/dev/null || true
                          ${pkgs.git}/bin/git add -A 2>/dev/null || true
                          ${pkgs.git}/bin/git commit -q -m "Vendored gem from bundle cache" --allow-empty 2>/dev/null || true

                          # Create branch with the name from Gemfile.lock if specified
                          if [ -n "$branch_name" ]; then
                            echo "  Creating branch '$branch_name' to match Gemfile.lock"
                            ${pkgs.git}/bin/git checkout -q -b "$branch_name" 2>/dev/null || ${pkgs.git}/bin/git checkout -q "$branch_name" 2>/dev/null || true
                          fi

                          # Create a ref for the revision so bundler can find it
                          if [ -n "$revision" ]; then
                            echo "  Creating ref for revision $revision"
                            ${pkgs.git}/bin/git update-ref "refs/heads/__bundler_ref_$revision" HEAD 2>/dev/null || true
                          fi
                        )
                      fi

                      # Extract gem name and set BUNDLE_LOCAL__ override
                      gem_name_raw=$(echo "$gem_basename" | sed 's/-[a-f0-9]\{7,\}$//')
                      gem_name_env=$(echo "$gem_name_raw" | tr '-' '_' | tr '[:lower:]' '[:upper:]')
                      export "BUNDLE_LOCAL__$gem_name_env=$cached_gem"
                      echo "  Set BUNDLE_LOCAL__$gem_name_env for cached git gem"
                    fi
                  done
                fi

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

                # Show gemset.nix status (no build test - can hang on new projects)
                if [ -f ./gemset.nix ]; then
                  echo "📦 gemset.nix found - you can try upgrading to normal mode:"
                  echo "   nix develop .#with-bundix  - Use bundlerEnv (no bundle exec needed)"
                  echo ""
                  echo "   If that fails with hash mismatches, regenerate with 'bundix' below"
                else
                  echo "📦 No gemset.nix found - this is expected for new projects"
                  echo "   Run 'bundix' below to generate it from Gemfile.lock"
                fi
                echo ""

                echo "🔧 Fix gemset.nix workflow:"
                echo "   bundix          - Regenerate gemset.nix from Gemfile.lock"
                echo "   exit            - Exit this shell"
                echo "   nix develop .#with-bundix  - Use bundlerEnv mode with new gemset.nix"
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
            if builtins.pathExists ./gemset.nix
            then let
              # Simple bundlerEnv without auto-fix for devshell
              shellGems = pkgs.bundlerEnv {
                name = "${framework}-gems";
                ruby = rubyPackage;
                gemdir = ./.;
                gemset = ./gemset.nix;
                gemConfig = pkgs.defaultGemConfig // {
                  ruby-vips = attrs: {
                    buildInputs = [ pkgs.vips ];
                  };
                };
              };
            in
              pkgs.mkShell {
                buildInputs = [rubyPackage bundlerPackage customBundix];
                shellHook =
                  defaultShellHook
                  + ''
                    export APP_ROOT=$(pwd)

                    # Complete Ruby environment isolation - prevent external Ruby artifacts
                    unset GEM_HOME
                    unset GEM_PATH
                    unset RUBYOPT
                    unset RUBYLIB

                    # Set up bundlerEnv environment - gems from Nix store only
                    export GEM_HOME=${shellGems}/lib/ruby/gems/${rubyMajorMinor}.0
                    export GEM_PATH=${shellGems}/lib/ruby/gems/${rubyMajorMinor}.0

                    # Critical: Point BUNDLE_GEMFILE to the local Gemfile, not Nix store
                    # This prevents bundler frozen mode errors when trying to modify Gemfile
                    export BUNDLE_GEMFILE=$APP_ROOT/Gemfile

                    # PATH: Real bundler FIRST (not bundlerEnv wrapper), then gems, Ruby, then user tools
                    # bundlerEnv's bundle wrapper hardcodes Nix store paths, so we use real bundler from bundlerPackage
                    export PATH=${bundlerPackage}/bin:${customBundix}/bin:${shellGems}/bin:${rubyPackage}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.gnused}/bin:${pkgs.gnugrep}/bin:${pkgs.findutils}/bin:${pkgs.gawk}/bin:${pkgs.git}/bin:${pkgs.which}/bin:${pkgs.less}/bin:$ORIGINAL_PATH

                    echo "💎 Bundix Environment: Direct gem access (Nix-isolated)"
                    echo "   Ruby: ${rubyVersion}"
                    echo "   Framework: ${framework} (auto-detected)"
                    echo "   GEM_HOME: $GEM_HOME"
                  '';
              }
            else
              pkgs.mkShell {
                buildInputs = [rubyPackage customBundix];
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
