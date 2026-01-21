{pkgs, ...}: {
  rubyVersion,
  gccVersion ? "latest",
  opensslVersion ? "3_2",
  src ? ./.,
  buildRailsApp,
  appName ? "rails-app", # Optional: Custom app name for Nix store differentiation
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
    nativeBuildInputs = [pkgs.rsync pkgs.coreutils pkgs.bash buildRailsApp pkgs.nix-ld];
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
      mkdir -p $out/app
      rsync -a --delete --include '.*' --exclude 'flake.nix' --exclude 'flake.lock' --exclude 'prepare-build.sh' . $out/app

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

# Rails-specific environment
export BUNDLE_PATH="$RAILS_ROOT/vendor/bundle"
export BUNDLE_GEMFILE="$RAILS_ROOT/Gemfile"

# PATH setup: Ruby first, then app bins, then existing PATH
export PATH="${rubyPackage}/bin:$RAILS_ROOT/bin:$PATH"

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
      ];

    shellHook = ''
      export PS1="shell:>"
      export PKG_CONFIG_PATH="${pkgs.curl.dev}/lib/pkgconfig:${pkgs.postgresql}/lib/pkgconfig"
      export LD_LIBRARY_PATH="${pkgs.curl}/lib:${pkgs.postgresql}/lib:${opensslPackage}/lib"
    '';
  };
in {
  inherit shell app;
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
          app
          usrBinDerivation
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
      config = {
        Cmd = [
          "${pkgs.bash}/bin/bash"
          "-c"
          "${
            if pkgs.stdenv.isLinux
            then "${pkgs.gosu}/bin/gosu app_user "
            else ""
          }${pkgs.goreman}/bin/goreman start web"
        ];
        Env = [
          "BUNDLE_PATH=/app/vendor/bundle"
          "BUNDLE_GEMFILE=/app/Gemfile"
          "RAILS_ENV=production"
          "RUBYLIB=${rubyPackage}/lib/ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/site_ruby/${rubyMajorMinor}.0"
          "RUBYOPT=-I${rubyPackage}/lib/ruby/${rubyMajorMinor}.0"
          "PATH=/app/vendor/bundle/bin:${rubyPackage}/bin:/usr/local/bin:/usr/bin:/bin"
          "TZDIR=/usr/share/zoneinfo"
        ];
        WorkingDir = "/app";
        enableFakechroot = !pkgs.stdenv.isDarwin;
        fakeRootCommands = ''
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
          chown -R 1000:1000 /app
          chmod -R u+w /app
        '';
      };
    };
}
