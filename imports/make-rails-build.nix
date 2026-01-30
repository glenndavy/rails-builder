{pkgs, ...}: {
  rubyVersion,
  gccVersion ? "latest",
  opensslVersion ? "3_2",
  src ? ./.,
  buildRailsApp,
  appName ? "rails-app", # Optional: Custom app name for Nix store differentiation
  bundlerPackage ? null, # Optional: Bundler built with correct Ruby version
  railsBuilderVersion ? "unknown", # Optional: Version string for debugging
  appRevision ? null, # Optional: Git revision of the app
  railsEnv ? "production", # Rails environment
}: let
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
  universalBuildInputs = [
    rubyPackage
    usrBinDerivation
    tzinfo
    opensslPackage
    pkgs.libpqxx
    pkgs.sqlite
    pkgs.libxml2
    pkgs.libxslt
    pkgs.zlib
    pkgs.libyaml
    pkgs.postgresql
    pkgs.zlib
    pkgs.libyaml
    pkgs.curl
    tzinfo
    pkgs.pkg-config
  ];

  app = pkgs.stdenv.mkDerivation {
    name = appName;
    inherit src;
    nativeBuildInputs = [pkgs.rsync pkgs.coreutils pkgs.bash buildRailsApp]
      ++ pkgs.lib.optionals pkgs.stdenv.isLinux [pkgs.nix-ld];
    buildInputs = universalBuildInputs
      ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
        pkgs.stdenv.cc.cc.lib  # Provides dynamic linker libraries for nix-ld
      ];

    # Make Ruby a runtime dependency so it's always available
    # This ensures the correct Ruby version is in the package closure
    propagatedBuildInputs = [ rubyPackage ];

    phases = [
      "unpackPhase" # optional, but harmless
      "patchPhase" # optional
      "preConfigure" # ← now this will run!
      #"configurePhase" # usually empty/no-op in Ruby apps
      "preBuild" # optional
      "buildPhase" # your full script
      "installPhase"
    ];

    preConfigure = ''
      echo ""
      echo "╔══════════════════════════════════════════════════════════════════╗"
      echo "║  bundler build: preconfigure                                     ║"
      echo "╚══════════════════════════════════════════════════════════════════╝"
      echo ""

      export HOME=$PWD
      export DATABASE_URL="postgresql://localhost/dummy_build_db"
      export PKG_CONFIG_PATH="${pkgs.curl.dev}/lib/pkgconfig:${pkgs.postgresql}/lib/pkgconfig''${PKG_CONFIG_PATH:+:}$PKG_CONFIG_PATH"
      export LD_LIBRARY_PATH="${pkgs.curl}/lib:${pkgs.postgresql}/lib:${opensslPackage}/lib''${LD_LIBRARY_PATH:+:}$LD_LIBRARY_PATH"

      # Configure nix-ld for running unpatched binaries (Linux only)
      ${pkgs.lib.optionalString pkgs.stdenv.isLinux ''
        export NIX_LD="${pkgs.stdenv.cc.bintools.dynamicLinker}"
        export NIX_LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}"
      ''}

      echo "  HOME: $HOME"
      echo "  DATABASE_URL: $DATABASE_URL"
      echo "  PKG_CONFIG_PATH: $PKG_CONFIG_PATH"
      echo "  LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
      ${pkgs.lib.optionalString pkgs.stdenv.isLinux ''
        echo "  NIX_LD: $NIX_LD"
        echo "  NIX_LD_LIBRARY_PATH: $NIX_LD_LIBRARY_PATH"
      ''}
    '';

    preBuild = ''
      echo "PRE-BUILD PHASE"
      # Pre-build hook - intentionally empty
      # (reserved for future environment setup, validation, or logging)
    '';
    buildPhase = ''
      echo "BUILD PHASE"
      export source=$PWD
    '';

    installPhase = ''
      echo "INSTALL PHASE"
      # Put files directly in $out (not $out/app) - consistent with bundix version
      mkdir -p $out
      rsync -a --delete --include '.*' --exclude 'flake.nix' --exclude 'flake.lock' --exclude 'prepare-build.sh' . $out/

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

# Ruby path (known at build time)
export RUBY_ROOT="${rubyPackage}"
${
  if bundlerPackage != null
  then ''export BUNDLER_ROOT="${bundlerPackage}"''
  else ""
}

# Rails-specific environment
export BUNDLE_PATH="$RAILS_ROOT/vendor/bundle"
export BUNDLE_GEMFILE="$RAILS_ROOT/Gemfile"

# PATH setup: Ruby first, then bundler (if exists), then app bins, then existing PATH
export PATH="${rubyPackage}/bin${
  if bundlerPackage != null
  then ":${bundlerPackage}/bin"
  else ""
}:$RAILS_ROOT/bin:$PATH"

# Library paths (for bundler-based builds)
export PKG_CONFIG_PATH="${pkgs.curl.dev}/lib/pkgconfig:${pkgs.postgresql}/lib/pkgconfig''${PKG_CONFIG_PATH:+:}''${PKG_CONFIG_PATH:-}"
export LD_LIBRARY_PATH="${pkgs.curl}/lib:${pkgs.postgresql}/lib:${opensslPackage}/lib''${LD_LIBRARY_PATH:+:}''${LD_LIBRARY_PATH:-}"
ENVEOF
      chmod +x $out/bin/rails-env

      # Keep metadata files for backwards compatibility
      mkdir -p $out/nix-support
      echo "${rubyPackage}" > $out/nix-support/ruby-path
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
      ++ (if bundlerPackage != null then [bundlerPackage] else []);

    shellHook = ''
      export PS1="shell:>"

      # PATH setup: bundlerPackage FIRST (correct version), then Ruby, then system
      # This ensures we use the bundler version from Gemfile.lock, not nixpkgs bundler
      ${if bundlerPackage != null
        then ''export PATH="${bundlerPackage}/bin:${rubyPackage}/bin:$PATH"''
        else ''export PATH="${rubyPackage}/bin:$PATH"''
      }

      export PKG_CONFIG_PATH="${pkgs.curl.dev}/lib/pkgconfig:${pkgs.postgresql}/lib/pkgconfig"
      export LD_LIBRARY_PATH="${pkgs.curl}/lib:${pkgs.postgresql}/lib:${opensslPackage}/lib"
    '';
  };
  # Create /etc files derivation
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

  # Writable directories
  writableDirs = pkgs.runCommand "writable-dirs" {} ''
    mkdir -p $out/tmp $out/var/tmp $out/app/tmp $out/app/log $out/app/storage
    mkdir -p $out/app/tmp/pids $out/app/tmp/cache
  '';

  # Docker entrypoint script - sets up bundler environment
  dockerEntrypoint = pkgs.writeShellScriptBin "docker-entrypoint" ''
    set -e
    cd /app

    # Ensure bundler environment is set up for interactive shells
    # These should match the Docker Env, but we set them explicitly
    # in case bash startup files modify the environment
    export BUNDLE_PATH=/app/vendor/bundle
    export BUNDLE_GEMFILE=/app/Gemfile
    export BUNDLE_FROZEN=true
    export GEM_HOME=/app/vendor/bundle/ruby/${rubyMajorMinor}.0
    export GEM_PATH=/app/vendor/bundle/ruby/${rubyMajorMinor}.0
    export PATH=/app/bin:/app/vendor/bundle/ruby/${rubyMajorMinor}.0/bin:${rubyPackage}/bin${if bundlerPackage != null then ":${bundlerPackage}/bin" else ""}:${pkgs.coreutils}/bin:${pkgs.bash}/bin:/usr/bin:/bin

    exec "$@"
  '';

  # Wrap app in /app directory for Docker
  # app derivation puts files directly in $out/, so we rsync to $out/app/
  appInPlace = pkgs.runCommand "app-in-place" {} ''
    mkdir -p $out/app
    ${pkgs.rsync}/bin/rsync -rltD --no-perms --chmod=ugo=rwX ${app}/ $out/app/
  '';

  # Base Docker contents (shared)
  dockerContentsBase =
    universalBuildInputs
    ++ [
      usrBinDerivation
      writableDirs
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
    # Include bundler so 'bundle exec' works
    ++ (if bundlerPackage != null then [ bundlerPackage ] else []);

  # Linux: minimal contents (app and /etc created in fakeRootCommands for proper permissions)
  dockerContentsLinux = dockerContentsBase ++ [ pkgs.gosu ];

  # Darwin: include app and /etc as derivations (no fakeroot available)
  dockerContentsDarwin = dockerContentsBase ++ [ etcFiles appInPlace ];

  # Common Docker config - consistent with bundix version
  dockerConfig = {
    Entrypoint =
      if pkgs.stdenv.isLinux
      then ["${pkgs.gosu}/bin/gosu" "app_user" "${dockerEntrypoint}/bin/docker-entrypoint"]
      else ["${dockerEntrypoint}/bin/docker-entrypoint"];
    Cmd = ["${pkgs.goreman}/bin/goreman" "start" "web"];
    Env = [
      "BUNDLE_PATH=/app/vendor/bundle"
      "BUNDLE_GEMFILE=/app/Gemfile"
      "BUNDLE_FROZEN=true"
      "GEM_HOME=/app/vendor/bundle/ruby/${rubyMajorMinor}.0"
      "GEM_PATH=/app/vendor/bundle/ruby/${rubyMajorMinor}.0"
      "RAILS_ENV=${railsEnv}"
      "RUBYLIB=${rubyPackage}/lib/ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/site_ruby/${rubyMajorMinor}.0"
      "PATH=/app/bin:/app/vendor/bundle/ruby/${rubyMajorMinor}.0/bin:${rubyPackage}/bin${if bundlerPackage != null then ":${bundlerPackage}/bin" else ""}:${pkgs.coreutils}/bin:${pkgs.bash}/bin:/usr/bin:/bin"
      "TZDIR=${tzinfo}/usr/share/zoneinfo"
      "TMPDIR=/app/tmp"
      "HOME=/app"
    ];
    WorkingDir = "/app";
  };

  # Linux: Full layered image with fakeroot for proper permissions
  dockerImageLinux = pkgs.dockerTools.buildLayeredImage {
    name = "rails-app-image";
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

      # Set permissions on mutable directories
      chmod 1777 /tmp /var/tmp
      chmod -R u+w /app/tmp /app/log /app/storage 2>/dev/null || true
    '';
    config = dockerConfig;
  };

  # Darwin: simpler image without fakeroot
  dockerImageDarwin = pkgs.dockerTools.buildImage {
    name = "rails-app-image";
    copyToRoot = pkgs.buildEnv {
      name = "rails-app-darwin-root";
      paths = dockerContentsDarwin;
      pathsToLink = [ "/" ];
    };
    config = dockerConfig;
  };

in {
  inherit shell app;
  dockerImage = if pkgs.stdenv.isLinux then dockerImageLinux else dockerImageDarwin;
}
