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
  appRevision ? null, # Optional: Git revision of the app (falls back to src.rev)
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
    pname = appName;
    version = railsBuilderVersion;
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
          # Remove any existing node_modules first (may be read-only from Nix unpack)
          if [ -d "${tailwindcssPackage}/node_modules" ]; then
            rm -rf ./node_modules 2>/dev/null || true
            ln -sfn "${tailwindcssPackage}/node_modules" ./node_modules
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
            # NOTE: This creates a NEW commit with a NEW SHA, which differs from the
            # original revision in Gemfile.lock. This causes bundler to see a mismatch.
            # See "GEMFILE.LOCK PRESERVATION WORKAROUND" in STAGE 4 for how we handle this.
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

      # ============================================================================
      # GEMFILE.LOCK PRESERVATION WORKAROUND
      # ============================================================================
      # Problem: For vendor/cache git gems, we initialize a git repo and commit
      # the contents (see STAGE 3 above). This creates a NEW commit with a NEW SHA,
      # different from the original revision in Gemfile.lock.
      #
      # When bundler runs with BUNDLE_LOCAL__ overrides, it validates that the
      # local gem's gemspec matches what's recorded in Gemfile.lock. Since we have
      # a different commit SHA, bundler sees a mismatch.
      #
      # With BUNDLE_FROZEN=true: bundler fails with "gemspecs changed" error
      # With BUNDLE_FROZEN=false: bundler "helpfully" updates Gemfile.lock
      #
      # Neither BUNDLE_DISABLE_LOCAL_REVISION_CHECK nor BUNDLE_DISABLE_CHECKSUM_VALIDATION
      # prevent the gemspec validation that causes this issue.
      #
      # Solution: Let bundler modify Gemfile.lock during asset precompilation,
      # then restore the original afterward. The final artifact gets the correct
      # Gemfile.lock that matches the source repository.
      # ============================================================================
      cp Gemfile.lock Gemfile.lock.original
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

      # Restore original Gemfile.lock - see "GEMFILE.LOCK PRESERVATION WORKAROUND" above
      # This ensures the final artifact has the correct Gemfile.lock from source,
      # not the modified version bundler created during asset precompilation
      echo "  Restoring original Gemfile.lock..."
      mv Gemfile.lock.original Gemfile.lock

      echo ""
      echo "╔══════════════════════════════════════════════════════════════════╗"
      echo "║  BUNDIX BUILD COMPLETE                                           ║"
      echo "╚══════════════════════════════════════════════════════════════════╝"
      echo ""
    '';

    installPhase = ''
      mkdir -p $out
      rsync -a --delete --include '.*' --exclude 'flake.nix' --exclude 'flake.lock' --exclude 'prepare-build.sh' . $out/

      # Remove vendor/cache - gems are already installed in vendor/bundle from Nix store
      # This reduces Docker image size since vendor/cache contains .gem archives and git gem directories
      rm -rf $out/vendor/cache

      # Write rails-builder version for debugging
      echo "${railsBuilderVersion}" > $out/.rails-builder-version

      # Write app git revision if available
      echo "${if appRevision != null then appRevision else if src ? rev then src.rev else "unknown"}" > $out/REVISION

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
      ]
      ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
        pkgs.darwin.apple_sdk.frameworks.CoreFoundation
        pkgs.darwin.apple_sdk.frameworks.CoreServices
        pkgs.darwin.apple_sdk.frameworks.Security
        pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
      ];

    shellHook = defaultShellHook;
  };
  # Derivation that creates writable directory structure for Docker
  # This becomes a layer in the image with proper permissions
  writableDirs = pkgs.runCommand "writable-dirs" {} ''
    mkdir -p $out/tmp $out/var/tmp $out/app/tmp $out/app/log $out/app/storage
    mkdir -p $out/app/tmp/pids $out/app/tmp/cache
  '';

  # Healthcheck script - checks goreman status and optionally HTTP endpoint
  healthcheckScript = pkgs.writeShellScriptBin "healthcheck" ''
    set -e

    # Configuration via environment variables
    ROLE="''${PROCFILE_ROLE:-web}"
    GOREMAN_RPC_PORT="''${GOREMAN_RPC_PORT:-8555}"
    HEALTHCHECK_PORT="''${PORT:-''${PROCFILE_BASE_PORT:-5000}}"
    HEALTHCHECK_PATH="''${HEALTHCHECK_PATH:-/health}"
    HEALTHCHECK_TIMEOUT="''${HEALTHCHECK_TIMEOUT:-5}"

    # Check goreman process status via RPC
    check_goreman() {
      local status
      status=$(${pkgs.goreman}/bin/goreman -p "$GOREMAN_RPC_PORT" run status "$ROLE" 2>&1) || {
        echo "FAIL: goreman status check failed: $status"
        return 1
      }

      # goreman run status outputs "*processname" for running processes
      # The asterisk prefix indicates the process is running
      if echo "$status" | ${pkgs.gnugrep}/bin/grep -q "^\*$ROLE$"; then
        echo "OK: goreman reports $ROLE is running"
        return 0
      else
        echo "FAIL: goreman reports $ROLE is not running: $status"
        return 1
      fi
    }

    # HTTP healthcheck for web-like roles
    check_http() {
      local url="http://127.0.0.1:''${HEALTHCHECK_PORT}''${HEALTHCHECK_PATH}"
      local response
      response=$(${pkgs.curl}/bin/curl -sf -o /dev/null -w "%{http_code}" \
        --max-time "$HEALTHCHECK_TIMEOUT" "$url" 2>&1) || {
        echo "FAIL: HTTP healthcheck to $url failed"
        return 1
      }

      if [ "$response" -ge 200 ] && [ "$response" -lt 400 ]; then
        echo "OK: HTTP healthcheck returned $response"
        return 0
      else
        echo "FAIL: HTTP healthcheck returned $response"
        return 1
      fi
    }

    # Main healthcheck logic
    echo "Healthcheck for role: $ROLE"

    # Always check goreman status
    check_goreman || exit 1

    # For web-like roles, also check HTTP endpoint
    case "$ROLE" in
      web|server|puma|unicorn|rails)
        if [ "''${HEALTHCHECK_SKIP_HTTP:-}" != "true" ]; then
          check_http || exit 1
        fi
        ;;
      *)
        # Non-web roles: goreman check is sufficient
        echo "OK: Non-web role, skipping HTTP check"
        ;;
    esac

    echo "OK: All healthchecks passed"
    exit 0
  '';

  # Docker entrypoint that ensures we're in the right directory
  dockerEntrypoint = pkgs.writeShellScriptBin "docker-entrypoint" ''
    set -e

    # Always run from /app - use absolute paths to be robust
    cd /app
    export PWD=/app
    export HOME=/app

    # Ensure bundlerEnv environment is set up for interactive shells
    # NOTE: Do NOT set BUNDLE_GEMFILE or BUNDLE_PATH here!
    # The bundlerEnv binstubs set these correctly via gen-bin-stubs.rb.
    export BUNDLE_FROZEN=true
    export BUNDLE_IGNORE_CONFIG=true
    export GEM_HOME="${gems}/lib/ruby/gems/${rubyMajorMinor}.0"
    export GEM_PATH="${gems}/lib/ruby/gems/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/gems/${rubyMajorMinor}.0"
    export PATH="${gems}/bin:${rubyPackage}/bin${if bundlerPackage != null then ":${bundlerPackage}/bin" else ""}${if tailwindcssPackage != null then ":${tailwindcssPackage}/bin" else ""}:${pkgs.coreutils}/bin:${pkgs.bash}/bin:/usr/bin:/bin"
    export RAILS_ENV="${railsEnv}"
    export RUBYLIB="${rubyPackage}/lib/ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/site_ruby/${rubyMajorMinor}.0"
    export TZDIR="${tzinfo}/usr/share/zoneinfo"
    export TMPDIR=/app/tmp
    ${if tailwindcssPackage != null then ''export TAILWINDCSS_INSTALL_DIR="${tailwindcssPackage}/bin"'' else ""}

    # If no arguments passed, run goreman with configurable Procfile and role
    # PROCFILE_NAME defaults to "Procfile", PROCFILE_ROLE defaults to "web"
    # PORT sets the port directly (takes precedence)
    # PROCFILE_BASE_PORT sets goreman's base port (defaults to 5000)
    BASE_PORT="''${PORT:-''${PROCFILE_BASE_PORT:-5000}}"
    if [ $# -eq 0 ]; then
      exec ${pkgs.goreman}/bin/goreman \
        -f "/app/''${PROCFILE_NAME:-Procfile}" \
        -b "$BASE_PORT" \
        start "''${PROCFILE_ROLE:-web}"
    fi

    # For custom commands, run them from /app
    exec "$@"
  '';

  # Create /etc files as a derivation (used on Darwin where fakeroot doesn't work)
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

  # Wrap app in /app directory structure (used on Darwin where fakeroot doesn't work)
  appInPlace = pkgs.runCommand "app-in-place" {} ''
    mkdir -p $out/app
    ${pkgs.rsync}/bin/rsync -a ${app}/ $out/app/
  '';

  # The bundlerEnv's confFiles contains the normalized Gemfile/Gemfile.lock
  # that bundler expects - this must be used for BUNDLE_GEMFILE
  gemsConfFiles = gems.confFiles or gems.passthru.confFiles or null;

  # Base Docker image contents (shared between Linux and Darwin)
  dockerContentsBase =
    universalBuildInputs
    ++ [
      gems
      usrBinDerivation
      writableDirs
      dockerEntrypoint
      healthcheckScript
      pkgs.goreman
      rubyPackage
      pkgs.curl
      opensslPackage
      pkgs.rsync
      pkgs.zlib
      pkgs.nodejs
      pkgs.bash
      pkgs.coreutils
      pkgs.less
    ]
    # Include bundler so 'bundle exec' works even in bundix environments
    # (Procfiles and binstubs typically use 'bundle exec')
    ++ (if bundlerPackage != null then [ bundlerPackage ] else [])
    # Include bundlerEnv's confFiles (normalized Gemfile for bundler)
    ++ (if gemsConfFiles != null then [ gemsConfFiles ] else []);

  # Linux: minimal contents (app and /etc created in fakeRootCommands for proper permissions)
  dockerContentsLinux = dockerContentsBase ++ [ pkgs.gosu ];

  # Darwin: include app and /etc as derivations (no fakeroot available)
  dockerContentsDarwin = dockerContentsBase ++ [ etcFiles appInPlace ];

  # Common Docker config
  dockerConfig = {
    Entrypoint =
      if pkgs.stdenv.isLinux
      then ["${pkgs.gosu}/bin/gosu" "app_user" "${dockerEntrypoint}/bin/docker-entrypoint"]
      else ["${dockerEntrypoint}/bin/docker-entrypoint"];
    # No Cmd - entrypoint handles default (goreman with PROCFILE_NAME/PROCFILE_ROLE)
    # NOTE: Do NOT set BUNDLE_GEMFILE or BUNDLE_PATH here!
    # The bundlerEnv binstubs set these correctly via gen-bin-stubs.rb.
    # Setting them here would override the binstub's values (which use confFiles).
    Env = [
      # Bundix: gems are in Nix store, bundler finds them via GEM_HOME/GEM_PATH
      "BUNDLE_FROZEN=true"
      "BUNDLE_IGNORE_CONFIG=true"
      "GEM_HOME=${gems}/lib/ruby/gems/${rubyMajorMinor}.0"
      "GEM_PATH=${gems}/lib/ruby/gems/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/gems/${rubyMajorMinor}.0"
      "RAILS_ENV=${railsEnv}"
      "RUBYLIB=${rubyPackage}/lib/ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/site_ruby/${rubyMajorMinor}.0"
      "PATH=${gems}/bin:${rubyPackage}/bin${if bundlerPackage != null then ":${bundlerPackage}/bin" else ""}:${pkgs.coreutils}/bin:${pkgs.bash}/bin:/usr/bin:/bin"
      "TZDIR=${tzinfo}/usr/share/zoneinfo"
      "TMPDIR=/app/tmp"
      "HOME=/app"
    ];
    WorkingDir = "/app";
    # Healthcheck using the /bin/healthcheck script
    # Checks goreman status and HTTP endpoint (for web roles)
    Healthcheck = {
      Test = ["CMD" "${healthcheckScript}/bin/healthcheck"];
      Interval = 30000000000;  # 30 seconds in nanoseconds
      Timeout = 10000000000;   # 10 seconds in nanoseconds
      Retries = 3;
      StartPeriod = 60000000000;  # 60 seconds startup grace period
    };
  };

  # Linux: Full layered image with fakeroot for proper permissions
  dockerImageLinux = pkgs.dockerTools.buildLayeredImage {
    name = "${appName}-image";
    contents = dockerContentsLinux;
    enableFakechroot = true;
    fakeRootCommands = ''
      # Create /etc files
      mkdir -p /etc
      cat > /etc/passwd <<-EOF
      root:x:0:0::/root:/bin/bash
      app_user:x:1000:1000:App User:/app:/bin/bash
      EOF
      cat > /etc/group <<-EOF
      root:x:0:
      app_user:x:1000:
      EOF
      cat > /etc/shadow <<-EOF
      root:*:18000:0:99999:7:::
      app_user:*:18000:0:99999:7:::
      EOF

      # Copy app into /app (use --no-perms to avoid permission issues from Nix store)
      mkdir -p /app
      ${pkgs.rsync}/bin/rsync -rltD --no-perms --chmod=ugo=rwX ${app}/ /app/

      # Set ownership on app directory
      chown -R 1000:1000 /app

      # Create and set permissions on mutable directories
      mkdir -p /tmp /var/tmp /app/tmp /app/tmp/pids /app/tmp/cache /app/log /app/storage
      chmod 1777 /tmp /var/tmp
      chmod -R u+w /app/tmp /app/log /app/storage
      chown -R 1000:1000 /app/tmp /app/log /app/storage
    '';
    config = dockerConfig;
  };

  # Darwin: Simple image without fakeroot (no permission setting)
  # Note: For production images with proper permissions, build on Linux
  # Use rsync to properly merge contents instead of buildEnv symlinks
  dockerRootDarwin = pkgs.runCommand "rails-app-root" {
    nativeBuildInputs = [ pkgs.rsync ];
  } ''
    mkdir -p $out

    # Merge all package contents using rsync
    # --ignore-existing prevents collisions, earlier packages take priority
    ${pkgs.lib.concatMapStringsSep "\n" (pkg: ''
      rsync -a --ignore-existing ${pkg}/ $out/ 2>/dev/null || true
    '') dockerContentsDarwin}
  '';

  dockerImageDarwin = pkgs.dockerTools.buildImage {
    name = "${appName}-image";
    copyToRoot = dockerRootDarwin;
    config = dockerConfig;
  };

  dockerImage = if pkgs.stdenv.isLinux then dockerImageLinux else dockerImageDarwin;

in {
  inherit shell app dockerImage;
}
