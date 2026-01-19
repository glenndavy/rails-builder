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
    name = "rails-app";
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
      [pkgs.rsync pkgs.coreutils pkgs.bash buildRailsApp pkgs.nodejs gems rubyPackage pkgs.nix-ld]
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

      echo ""
      echo "┌──────────────────────────────────────────────────────────────────┐"
      echo "│ STAGE 4: Asset Precompilation                                    │"
      echo "└──────────────────────────────────────────────────────────────────┘"
      echo "  PATH: $PATH"
      echo "  GEM_HOME: $GEM_HOME"
      echo "  GEM_PATH: $GEM_PATH"
      echo "  Running: rails assets:precompile"
      # Use direct Rails command (bundlerEnv approach - no bundle exec)
      rails assets:precompile

      echo ""
      echo "╔══════════════════════════════════════════════════════════════════╗"
      echo "║  BUNDIX BUILD COMPLETE                                           ║"
      echo "╚══════════════════════════════════════════════════════════════════╝"
      echo ""
    '';

    installPhase = ''
      mkdir -p $out/app
      rsync -a --delete --include '.*' --exclude 'flake.nix' --exclude 'flake.lock' --exclude 'prepare-build.sh' . $out/app
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
          gems
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
      config = {
        Cmd =
          if pkgs.stdenv.isLinux
          then ["${pkgs.bash}/bin/bash" "-c" "${pkgs.gosu}/bin/gosu app_user ${pkgs.goreman}/bin/goreman start web"]
          else ["${pkgs.bash}/bin/bash" "-c" "${pkgs.goreman}/bin/goreman start web"];
        Env = [
          "BUNDLE_PATH=/app/vendor/bundle"
          "BUNDLE_GEMFILE=/app/Gemfile"
          "GEM_PATH=/app/vendor/bundle/ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/gems/${rubyMajorMinor}.0:/app/vendor/bundle/ruby/${rubyMajorMinor}.0/bundler/gems"
          "RAILS_ENV=production"
          "RUBYLIB=${rubyPackage}/lib/ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/site_ruby/${rubyMajorMinor}.0"
          "RUBYOPT=-I${rubyPackage}/lib/ruby/${rubyMajorMinor}.0"
          "PATH=/app/vendor/bundle/bin:${rubyPackage}/bin:/usr/local/bin:/usr/bin:/bin"
          "TZDIR=/usr/share/zoneinfo"
        ];
        User = "app_user:app_user";
        WorkingDir = "/app";
      };
    };
}
