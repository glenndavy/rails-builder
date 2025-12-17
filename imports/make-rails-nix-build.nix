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
  ...
}: let
  # Build LD_LIBRARY_PATH from universalBuildInputs at Nix evaluation time
  # This ensures FFI-based gems can find native libraries
  buildInputLibPaths = builtins.concatStringsSep ":" (
    builtins.filter (p: p != "") (
      map (input:
        if builtins.pathExists (input + "/lib")
        then "${input}/lib"
        else ""
      ) universalBuildInputs
    )
  );

  app = pkgs.stdenv.mkDerivation {
    name = "rails-app";
    inherit src;
    nativeBuildInputs =
      [pkgs.rsync pkgs.coreutils pkgs.bash buildRailsApp pkgs.nodejs gems rubyPackage]
      ++ (
        if builtins.pathExists (src + "/yarn.lock")
        then [pkgs.yarnConfigHook pkgs.yarnInstallHook]
        else []
      );
    buildInputs = universalBuildInputs;

    # Set LD_LIBRARY_PATH for FFI-based gems (ruby-vips, etc.)
    LD_LIBRARY_PATH = buildInputLibPaths;

    preConfigure = ''
      export HOME=$PWD
      if [ -f ./yarn.lock ]; then
       yarn config --offline set yarn-offline-mirror ${yarnOfflineCache}
      fi
    '';

    buildPhase = ''
      export HOME=$PWD
      export source=$PWD
      if [ -f ./yarn.lock ]; then
        yarn install --offline --frozen-lockfile
      fi
      mkdir -p vendor/bundle/ruby/${rubyMajorMinor}.0
      # Copy gems from bundlerEnv to vendor for compatibility
      cp -r ${gems}/lib/ruby/gems/${rubyMajorMinor}.0/* vendor/bundle/ruby/${rubyMajorMinor}.0/

      # Set up environment for direct gem access (no bundle exec needed)
      export GEM_HOME=${gems}/lib/ruby/gems/${rubyMajorMinor}.0
      export GEM_PATH=${gems}/lib/ruby/gems/${rubyMajorMinor}.0
      export PATH=${gems}/bin:${rubyPackage}/bin:$PATH

      # LD_LIBRARY_PATH is set as a derivation attribute for FFI-based gems
      echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"

      # Use direct Rails command (bundlerEnv approach - no bundle exec)
      rails assets:precompile
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
        ] ++ (if pkgs.stdenv.isLinux then [pkgs.gosu] else []);
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
        Cmd = if pkgs.stdenv.isLinux
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
