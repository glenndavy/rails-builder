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
    #nativeBuildInputs = [pkgs.rsync pkgs.coreutils pkgs.bash buildRailsApp pkgs.nodejs pkgs.yarnConfigHook pkgs.yarnInstallHook gems rubyPackage];
    buildInputs = universalBuildInputs;
    #yarnFlags = ["--offline" "--frozen-lockfile"];

    preConfigure = ''
      export HOME=$PWD
      echo "DEBUG: configurePhase start" >&2
      if [ -f ./yarn.lock ]; then
       yarn config --offline set yarn-offline-mirror ${yarnOfflineCache}
      fi
    '';

    buildPhase = ''
      set -x
      echo "DEBUG: rails-app build phase start" >&2
      export HOME=$PWD
      export source=$PWD
      if [ -f ./yarn.lock ]; then
      yarn install ${toString ["--offline" "--frozen-lockfile"]}
      fi
      mkdir -p vendor/bundle/ruby/${rubyMajorMinor}.0
      cp -r ${gems}/lib/ruby/gems/${rubyMajorMinor}.0/* vendor/bundle/ruby/${rubyMajorMinor}.0/
      export BUNDLE_PATH=vendor/bundle
      export PATH=vendor/bundle/ruby/${rubyMajorMinor}.0/bin:$PATH
      bundle env
      bundle exec rails assets:precompile
      echo "DEBUG: rails-app build phase done" >&2
    '';
    installPhase = ''
      echo "DEBUG: rails-app install phase start" >&2
      mkdir -p $out/app
      rsync -a --delete --include '.*' --exclude 'flake.nix' --exclude 'flake.lock' --exclude 'prepare-build.sh' . $out/app
      echo "DEBUG: Filesystem setup completed" >&2
      echo "DEBUG: rails-app install phase done" >&2
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
          pkgs.gosu
          pkgs.nodejs
          pkgs.bash
          pkgs.coreutils
        ];
      enableFakechroot = true;
      fakeRootCommands = ''
            set -x
            echo "DEBUG: Execuiting dockerImage fakeroot commands"
        mkdir -p /etc
        cat > /etc/passwd <<-EOF
        root:x:0:0::/root:/bin/bash
        app_user:x:1000:1000:App User:/app:/bin/bash
        EOF
        cat > /etc/group <<-EOF
        root:x:0:
        app_user:x:1000:
        EOF
        # Optional shadow
        cat > /etc/shadow <<-EOF
        root:*:18000:0:99999:7:::
        app_user:*:18000:0:99999:7:::
        EOF
        chown -R 1000:1000 /app
        chmod -R u+w /app
            echo "DEBUG: Done execuiting dockerImage fakeroot commands"
      '';
      config = {
        Cmd = ["${pkgs.bash}/bin/bash" "-c" "${pkgs.gosu}/bin/gosu app_user ${pkgs.goreman}/bin/goreman start web"];
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
        #runAsRoot = ''
        #  chown -R 1000:1000 /app
        #'';

        #extraCommands = ''
        #  echo "DEBUG: Starting extraCommands" >&2
        #  mkdir -p etc
        #  cat > etc/passwd <<-EOF
        #  root:x:0:0::/root:/bin/bash
        #  app_user:x:1000:1000:App User:/app:/bin/bash
        #  EOF
        #  cat > etc/group <<-EOF
        #  root:x:0:
        #  app_user:x:1000:
        #  EOF
        #  # Optional shadow (for no password)
        #  cat > etc/shadow <<-EOF
        #  root:*:18000:0:99999:7:::
        #  app_user:*:18000:0:99999:7:::
        #  EOF
        #  # Ownership (app dir from contents)
        #  chown -R 1000:1000 app
        #  chmod -R u+w app
        #  echo "DEBUG: Contents of etc:" >&2
        #  ls -l etc >&2
        #'';
      };
    };
}
