# imports/make-rails-nix-build.nix
{
  pkgs,
  rubyVersion,
  gccVersion ? "latest",
  opensslVersion ? "3_2",
  src ? ./.,
  buildRailsApp,
  gems,
  nodeModules,
  universalBuildInputs,
  rubyPackage,
  rubyMajorMinor,
  yarnOfflineCache,
  gccPackage,
  opensslPackage,
  usrBinDerivation,
  tzinfo,
  defaultShellHook,
  tailwindcssPackage ? null, # Optional: Nix-provided tailwindcss binary
  bundlerPackage ? null, # Optional: Bundler built with correct Ruby version
  appName ? "rails-app", # Optional: Custom app name for Nix store differentiation
  railsEnv ? "production", # Rails environment for asset precompilation
  railsBuilderVersion ? "unknown", # Version of rails-builder for debugging
  ...
}: let
  # Build LD_LIBRARY_PATH from universalBuildInputs at Nix evaluation time
  # Simply append /lib to each input path - the directory may not exist but that's OK
  # FFI will just skip non-existent paths
  buildInputLibPaths = builtins.concatStringsSep ":" (
    map (input: "${input}/lib") universalBuildInputs
  );

  # 1. Collect all /lib/pkgconfig directories (most common location)
  pkgConfigPaths = builtins.concatStringsSep ":" (
    map (input: "${input}/lib/pkgconfig") universalBuildInputs
  );

  # 2. Optional: also include /share/pkgconfig if any of your inputs use it
  #    (safe to always include — pkg-config will simply ignore non-existent paths)
  pkgConfigPathsExtra = builtins.concatStringsSep ":" (
    map (input: "${input}/share/pkgconfig") universalBuildInputs
  );

  # 3. Combine both (use : separator again)
  fullPkgConfigPath = "${pkgConfigPaths}:${pkgConfigPathsExtra}";

  app = pkgs.stdenv.mkDerivation {
    name = appName;
    inherit src;

    phases = [
      "unpackPhase" # optional, but harmless
      "patchPhase" # optional
      "preConfigure" # ← now this will run!
      #"configurePhase" # usually empty/no-op in Ruby apps
      "preBuild" # optional
      "buildPhase" # your full script
      "installPhase"
    ];

    nativeBuildInputs =
      [pkgs.rsync pkgs.coreutils pkgs.bash buildRailsApp pkgs.nodejs gems rubyPackage pkgs.git]
      ++ pkgs.lib.optionals pkgs.stdenv.isLinux [pkgs.nix-ld]
      ++ universalBuildInputs # Include all buildInputs in nativeBuildInputs for library access
      ++ (
        if builtins.pathExists (src + "/yarn.lock")
        then [pkgs.yarnConfigHook pkgs.yarnInstallHook]
        else []
      )
      ++ (
        if tailwindcssPackage != null
        then [tailwindcssPackage]
        else []
      );
    buildInputs = universalBuildInputs
      ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
        pkgs.stdenv.cc.cc.lib  # Provides dynamic linker libraries for nix-ld
      ];

    # Make Ruby and optionally Bundler runtime dependencies
    # This ensures the correct versions are in the package closure
    propagatedBuildInputs = [ rubyPackage ]
      ++ (if bundlerPackage != null then [ bundlerPackage ] else []);

    # Set LD_LIBRARY_PATH for FFI-based gems (ruby-vips, etc.)
    LD_LIBRARY_PATH = buildInputLibPaths;

    preConfigure = ''
      echo ""
      echo "╔══════════════════════════════════════════════════════════════════╗"
      echo "║  bundix build: preconfigure for bundlerEnv                       ║"
      echo "╚══════════════════════════════════════════════════════════════════╝"
      echo ""

      export LD_LIBRARY_PATH="${buildInputLibPaths}''${LD_LIBRARY_PATH:+:}$LD_LIBRARY_PATH"
      export PKG_CONFIG_PATH="${fullPkgConfigPath}''${PKG_CONFIG_PATH:+:}$PKG_CONFIG_PATH"
      export HOME=$PWD
      if [ -f ./yarn.lock ]; then
       yarn config --offline set yarn-offline-mirror ${yarnOfflineCache}
      fi
    '';

    preBuild = ''
      echo "PRE-BUILD PHASE"
      # Pre-build hook - intentionally empty
      # (reserved for future environment setup, validation, or logging)
    '';

    buildPhase = ''
      export HOME=$PWD
      export source=$PWD
      export DATABASE_URL="postgresql://localhost/dummy_build_db"

      # Configure nix-ld for running unpatched binaries (Linux only)
      ${pkgs.lib.optionalString pkgs.stdenv.isLinux ''
        export NIX_LD="${pkgs.stdenv.cc.bintools.dynamicLinker}"
        export NIX_LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}"
      ''}

      echo ""
      echo "╔══════════════════════════════════════════════════════════════════╗"
      echo "║  bundix build: rails application (bundlerenv)                    ║"
      echo "╚══════════════════════════════════════════════════════════════════╝"
      echo ""

      echo "┌──────────────────────────────────────────────────────────────────┐"
      echo "│ STAGE 1: Environment Setup                                       │"
      echo "└──────────────────────────────────────────────────────────────────┘"
      echo "  HOME: $HOME"
      echo "  Ruby: ${rubyPackage}/bin/ruby"
      echo "  Gems: ${gems}"
      echo "  LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
      echo "  DATABASE_URL: $DATABASE_URL"
      ${pkgs.lib.optionalString pkgs.stdenv.isLinux ''
        echo "  NIX_LD: $NIX_LD"
        echo "  NIX_LD_LIBRARY_PATH: $NIX_LD_LIBRARY_PATH"
      ''}

      ${
        if tailwindcssPackage != null
        then ''
          # Point tailwindcss-ruby gem to Nix-provided binary via TAILWINDCSS_INSTALL_DIR
          # The gem will look for $TAILWINDCSS_INSTALL_DIR/tailwindcss
          export TAILWINDCSS_INSTALL_DIR="${tailwindcssPackage}/bin"
          echo "  TAILWINDCSS_INSTALL_DIR: $TAILWINDCSS_INSTALL_DIR"

          # Symlink node_modules so tailwindcss can resolve @import "tailwindcss"
          # The CLI uses enhanced-resolve which doesn't respect NODE_PATH
          if [ -d "${tailwindcssPackage}/node_modules" ]; then
            ln -sf "${tailwindcssPackage}/node_modules" ./node_modules
            echo "  Symlinked node_modules for tailwindcss resolution"
          fi
        ''
        else ""
      }

      echo ""
      echo "┌──────────────────────────────────────────────────────────────────┐"
      echo "│ STAGE 2: Yarn Install (if yarn.lock exists)                      │"
      echo "└──────────────────────────────────────────────────────────────────┘"
      if [ -f ./yarn.lock ]; then
        echo "  Found yarn.lock, running yarn install..."
        yarn install --offline --frozen-lockfile
      else
        echo "  No yarn.lock found, skipping yarn install"
      fi

      echo ""
      echo "┌──────────────────────────────────────────────────────────────────┐"
      echo "│ STAGE 3: Copy Gems to vendor/bundle                              │"
      echo "└──────────────────────────────────────────────────────────────────┘"
      mkdir -p vendor/bundle/ruby/${rubyMajorMinor}.0
      echo "  Copying gems from ${gems}/lib/ruby/gems/${rubyMajorMinor}.0/..."
      echo "  (Following symlinks to create writable copies)"
      cp -rL ${gems}/lib/ruby/gems/${rubyMajorMinor}.0/* vendor/bundle/ruby/${rubyMajorMinor}.0/
      echo "  Making copied gems writable..."
      chmod -R u+w vendor/bundle/ruby/${rubyMajorMinor}.0/

      # Create bundler/gems directory structure for git gems from vendor/cache
      # This allows Bundler to find git gems that were converted to path sources in gemset.nix
      echo "  Setting up bundler/gems structure for cached git gems..."
      mkdir -p vendor/bundle/ruby/${rubyMajorMinor}.0/bundler/gems

      # For git gems in vendor/cache, we need to:
      # 1. Initialize a git repo (bundler requires it for local overrides)
      # 2. Set BUNDLE_LOCAL__<gem_name> to point to the local path
      # This prevents bundler from trying to fetch from the original git remote
      if [ -d vendor/cache ]; then
        for cached_gem in vendor/cache/*-*; do
          if [ -d "$cached_gem" ] && [ -f "$cached_gem/.bundlecache" ]; then
            gem_basename=$(basename "$cached_gem")
            echo "    Setting up $gem_basename for bundler..."

            # Symlink to bundler/gems for gem loading
            ln -sf "$PWD/$cached_gem" vendor/bundle/ruby/${rubyMajorMinor}.0/bundler/gems/$gem_basename

            # Initialize git repo if not already present (needed for BUNDLE_LOCAL__ override)
            if [ ! -d "$cached_gem/.git" ]; then
              echo "    Initializing git repo in $gem_basename for bundler local override..."

              # Extract branch name from Gemfile.lock for this gem
              # Look for GIT block with matching remote, then find the branch line
              gem_remote_pattern=$(echo "$gem_basename" | sed 's/-[a-f0-9]\{7,\}$//')
              branch_name=$(${pkgs.gawk}/bin/awk '
                /^GIT/ { in_git=1; branch=""; next }
                /^[A-Z]/ && !/^GIT/ { in_git=0 }
                in_git && /remote:.*'"$gem_remote_pattern"'/ { found=1 }
                in_git && found && /branch:/ { gsub(/.*branch: */, ""); print; exit }
              ' Gemfile.lock)

              # Also extract the revision from Gemfile.lock
              revision=$(${pkgs.gawk}/bin/awk '
                /^GIT/ { in_git=1; next }
                /^[A-Z]/ && !/^GIT/ { in_git=0 }
                in_git && /remote:.*'"$gem_remote_pattern"'/ { found=1 }
                in_git && found && /revision:/ { gsub(/.*revision: */, ""); print; exit }
              ' Gemfile.lock)

              (
                cd "$cached_gem"
                ${pkgs.git}/bin/git init -q
                ${pkgs.git}/bin/git config user.email "nix-build@localhost"
                ${pkgs.git}/bin/git config user.name "Nix Build"
                ${pkgs.git}/bin/git add -A
                ${pkgs.git}/bin/git commit -q -m "Vendored gem from bundle cache" --allow-empty

                # Create branch with the name from Gemfile.lock if specified
                if [ -n "$branch_name" ]; then
                  echo "    Creating branch '$branch_name' to match Gemfile.lock"
                  ${pkgs.git}/bin/git checkout -q -b "$branch_name" 2>/dev/null || ${pkgs.git}/bin/git checkout -q "$branch_name" 2>/dev/null || true
                fi

                # Create a tag with the revision hash so bundler can find it
                if [ -n "$revision" ]; then
                  echo "    Creating ref for revision $revision"
                  # Create a refs/heads entry that matches the revision
                  ${pkgs.git}/bin/git update-ref "refs/heads/__bundler_ref_$revision" HEAD 2>/dev/null || true
                fi
              )
            fi

            # Extract gem name from directory (format: gem-name-revision)
            # e.g., opscare-reports-87e403c81899 -> opscare-reports -> opscare_reports
            # Note: gem names use underscores, directory names use hyphens
            gem_name_with_revision="$gem_basename"
            # Remove the revision suffix (last segment after final hyphen, if it looks like a hash)
            gem_name_raw=$(echo "$gem_name_with_revision" | sed 's/-[a-f0-9]\{7,\}$//')
            # Convert hyphens to underscores for bundler env var (BUNDLE_LOCAL__GEM_NAME)
            gem_name_env=$(echo "$gem_name_raw" | tr '-' '_' | tr '[:lower:]' '[:upper:]')

            echo "    Setting BUNDLE_LOCAL__$gem_name_env=$PWD/$cached_gem"
            export "BUNDLE_LOCAL__$gem_name_env=$PWD/$cached_gem"
          fi
        done
      fi
      echo "  Done copying gems"

      # Set up environment for direct gem access (no bundle exec needed)
      # Point to our writable vendor/bundle copy, not the read-only Nix store
      export GEM_HOME=$PWD/vendor/bundle/ruby/${rubyMajorMinor}.0
      export GEM_PATH=$PWD/vendor/bundle/ruby/${rubyMajorMinor}.0
      export PATH=${gems}/bin:${rubyPackage}/bin${
        if tailwindcssPackage != null
        then ":${tailwindcssPackage}/bin"
        else ""
      }:$PATH

      # Configure Bundler to use cached gems from vendor/cache for git gems
      # This prevents Bundler from trying to access git during asset precompilation
      export BUNDLE_CACHE_PATH=$PWD/vendor/cache
      export BUNDLE_DISABLE_LOCAL_BRANCH_CHECK=true
      export BUNDLE_DISABLE_LOCAL_REVISION_CHECK=true
      export BUNDLE_ALLOW_OFFLINE_INSTALL=true
      export BUNDLE_GEMFILE=$PWD/Gemfile

      # CRITICAL: Ignore any .bundle/config files that bundlerEnv might have created
      # These config files can override environment variables and cause "frozen" conflicts
      export BUNDLE_IGNORE_CONFIG=true

      # Disable checksum validation which can fail for git gems with local overrides
      export BUNDLE_DISABLE_CHECKSUM_VALIDATION=true

      # Remove any existing .bundle/config to prevent conflicts
      rm -rf .bundle/config $HOME/.bundle/config 2>/dev/null || true

      # Handle frozen mode based on whether local git gem overrides are present
      # BUNDLE_LOCAL__ overrides can cause gemspec mismatches which conflict with frozen mode
      # For asset precompilation, we generally want frozen=false to avoid lockfile update attempts
      if env | grep -q "^BUNDLE_LOCAL__"; then
        echo "  Note: Disabling frozen/deployment mode due to BUNDLE_LOCAL__ overrides"
      fi
      # Always disable frozen mode during asset precompilation to prevent lockfile conflicts
      # The gems are already installed by bundlerEnv, we just need to compile assets
      export BUNDLE_FROZEN=false
      export BUNDLE_DEPLOYMENT=false

      echo ""
      echo "┌──────────────────────────────────────────────────────────────────┐"
      echo "│ STAGE 4: Asset Precompilation                                    │"
      echo "└──────────────────────────────────────────────────────────────────┘"

      # Set Rails environment for asset precompilation
      export RAILS_ENV="${railsEnv}"
      export SECRET_KEY_BASE="dummy_secret_for_asset_precompilation"

      echo "  RAILS_ENV: $RAILS_ENV"
      echo "  PATH: $PATH"
      echo "  GEM_HOME: $GEM_HOME"
      echo "  GEM_PATH: $GEM_PATH"
      echo "  BUNDLE_FROZEN: ''${BUNDLE_FROZEN:-<not set>}"
      echo "  BUNDLE_DEPLOYMENT: ''${BUNDLE_DEPLOYMENT:-<not set>}"
      echo "  BUNDLE_IGNORE_CONFIG: ''${BUNDLE_IGNORE_CONFIG:-<not set>}"
      echo "  BUNDLE_DISABLE_CHECKSUM_VALIDATION: ''${BUNDLE_DISABLE_CHECKSUM_VALIDATION:-<not set>}"
      echo "  BUNDLE_CACHE_PATH: $BUNDLE_CACHE_PATH"
      echo "  BUNDLE_DISABLE_LOCAL_BRANCH_CHECK: $BUNDLE_DISABLE_LOCAL_BRANCH_CHECK"
      echo "  BUNDLE_DISABLE_LOCAL_REVISION_CHECK: $BUNDLE_DISABLE_LOCAL_REVISION_CHECK"
      echo "  BUNDLE_ALLOW_OFFLINE_INSTALL: $BUNDLE_ALLOW_OFFLINE_INSTALL"
      # Show any BUNDLE_LOCAL__ overrides that were set
      env | grep "^BUNDLE_LOCAL__" | while read line; do
        echo "  $line"
      done || true

      echo "  Running: rails assets:precompile"
      rails assets:precompile

      echo ""
      echo "╔══════════════════════════════════════════════════════════════════╗"
      echo "║  BUNDIX BUILD COMPLETE                                           ║"
      echo "╚══════════════════════════════════════════════════════════════════╝"
      echo ""
    '';

    installPhase = ''
      mkdir -p $out
      rsync -a --delete --include '.*' --exclude 'flake.nix' --exclude 'flake.lock' --exclude 'prepare-build.sh' . $out/

      # Write rails-builder version for debugging
      echo "${railsBuilderVersion}" > $out/.rails-builder-version

      # Write app git revision if available
      echo "${if src ? rev then src.rev else "unknown"}" > $out/REVISION

      # Create comprehensive environment setup script with all build-time facts
      mkdir -p $out/bin
      cat > $out/bin/rails-env <<'ENVEOF'
#!/usr/bin/env bash
# Rails environment setup - generated at build time with all known facts
# Source this script to set up the environment for running the Rails app

# Sanity check: RAILS_ROOT must be set by caller
if [ -z "$RAILS_ROOT" ]; then
  echo "Error: RAILS_ROOT must be set before sourcing rails-env" >&2
  exit 1
fi

# Ruby and Bundler paths (known at build time)
export RUBY_ROOT="${rubyPackage}"
${
  if bundlerPackage != null
  then ''export BUNDLER_ROOT="${bundlerPackage}"''
  else ""
}

# Gem paths for bundix build (gems in vendor/bundle)
export GEM_HOME="$RAILS_ROOT/vendor/bundle/ruby/${rubyMajorMinor}.0"
export GEM_PATH="$RAILS_ROOT/vendor/bundle/ruby/${rubyMajorMinor}.0"

# Rails-specific environment
export BUNDLE_GEMFILE="$RAILS_ROOT/Gemfile"

# PATH setup: Ruby first, then gems, then bundler (if exists), then existing PATH
export PATH="${rubyPackage}/bin:${gems}/bin${
  if bundlerPackage != null
  then ":${bundlerPackage}/bin"
  else ""
}${
  if tailwindcssPackage != null
  then ":${tailwindcssPackage}/bin"
  else ""
}:$PATH"

# Library paths for FFI gems (ruby-vips, etc.)
export LD_LIBRARY_PATH="${buildInputLibPaths}''${LD_LIBRARY_PATH:+:}''${LD_LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="${fullPkgConfigPath}''${PKG_CONFIG_PATH:+:}''${PKG_CONFIG_PATH:-}"

# Optional: Tailwindcss integration
${
  if tailwindcssPackage != null
  then ''export TAILWINDCSS_INSTALL_DIR="${tailwindcssPackage}/bin"''
  else ""
}
ENVEOF
      chmod +x $out/bin/rails-env

      # Keep metadata files for backwards compatibility
      mkdir -p $out/nix-support
      echo "${rubyPackage}" > $out/nix-support/ruby-path
      ${
        if bundlerPackage != null
        then ''echo "${bundlerPackage}" > $out/nix-support/bundler-path''
        else ""
      }
    '';
  };

  shell = pkgs.mkShell {
    buildInputs =
      universalBuildInputs
      ++ [
        gccPackage
        pkgs.pkg-config
        pkgs.gosu
        pkgs.rsync
        pkgs.nodejs
      ];

    shellHook = defaultShellHook;
  };
  # Derivation that creates writable directory structure for Docker
  # This becomes a layer in the image with proper permissions
  writableDirs = pkgs.runCommand "writable-dirs" {} ''
    mkdir -p $out/tmp $out/var/tmp $out/app/tmp $out/app/log $out/app/storage
    mkdir -p $out/app/tmp/pids $out/app/tmp/cache
  '';

  # Docker entrypoint that ensures we're in the right directory
  dockerEntrypoint = pkgs.writeShellScriptBin "docker-entrypoint" ''
    set -e
    cd /app
    exec "$@"
  '';
in {
  inherit shell app;
  # Create /etc files as a derivation (works on both Linux and Darwin)
  etcFiles = pkgs.runCommand "etc-files" {} ''
    mkdir -p $out/etc
    cat > $out/etc/passwd <<-EOF
    root:x:0:0::/root:/bin/bash
    app_user:x:1000:1000:App User:/app:/bin/bash
    EOF
    cat > $out/etc/group <<-EOF
    root:x:0:
    app_user:x:1000:
    EOF
    cat > $out/etc/shadow <<-EOF
    root:*:18000:0:99999:7:::
    app_user:*:18000:0:99999:7:::
    EOF
  '';

  # Wrap app in /app directory structure
  appInPlace = pkgs.runCommand "app-in-place" {} ''
    mkdir -p $out/app
    ${pkgs.rsync}/bin/rsync -a ${app}/ $out/app/
  '';

  dockerImage = let
    commitSha =
      if src ? rev
      then builtins.substring 0 8 src.rev
      else "latest";
  in
    pkgs.dockerTools.buildLayeredImage {
      name = "rails-app-image";
      contents =
        universalBuildInputs
        ++ [
          gems
          usrBinDerivation
          writableDirs
          etcFiles
          appInPlace
          dockerEntrypoint
          pkgs.goreman
          rubyPackage
          pkgs.curl
          opensslPackage
          pkgs.rsync
          pkgs.zlib
          pkgs.nodejs
          pkgs.bash
          pkgs.coreutils
        ]
        ++ (
          if pkgs.stdenv.isLinux
          then [pkgs.gosu]
          else []
        );
      enableFakechroot = false;
      # fakeRootCommands removed - doesn't work on Darwin
      # /etc files and app are now included via derivations in contents
      config = {
        Entrypoint =
          if pkgs.stdenv.isLinux
          then ["${pkgs.gosu}/bin/gosu" "app_user" "${dockerEntrypoint}/bin/docker-entrypoint"]
          else ["${dockerEntrypoint}/bin/docker-entrypoint"];
        Cmd = ["${pkgs.goreman}/bin/goreman" "start" "web"];
        Env = [
          "BUNDLE_PATH=/app/vendor/bundle"
          "BUNDLE_GEMFILE=/app/Gemfile"
          "GEM_HOME=${gems}/lib/ruby/gems/${rubyMajorMinor}.0"
          "GEM_PATH=${gems}/lib/ruby/gems/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/gems/${rubyMajorMinor}.0"
          "RAILS_ENV=${railsEnv}"
          "RUBYLIB=${rubyPackage}/lib/ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/site_ruby/${rubyMajorMinor}.0"
          "PATH=${gems}/lib/ruby/gems/${rubyMajorMinor}.0/bin:${rubyPackage}/bin:${pkgs.coreutils}/bin:${pkgs.bash}/bin:/usr/bin:/bin"
          "TZDIR=${tzinfo}/usr/share/zoneinfo"
          "TMPDIR=/app/tmp"
          "HOME=/app"
        ];
        WorkingDir = "/app";
      };
    };
}
