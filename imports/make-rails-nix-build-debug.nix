# Debug version of make-rails-nix-build.nix to isolate boolean issue
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
  # Debug: Test each parameter separately
  debugInfo = pkgs.writeText "debug-params" ''
    rubyMajorMinor: ${toString rubyMajorMinor}
    gems: ${toString gems}
    yarnOfflineCache: ${toString yarnOfflineCache}
    rubyPackage: ${toString rubyPackage}
  '';

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

    preConfigure = ''
      export HOME=$PWD
      echo "DEBUG: configurePhase start" >&2
      echo "DEBUG: Debug info from ${debugInfo}" >&2
      if [ -f ./yarn.lock ]; then
       yarn config --offline set yarn-offline-mirror ${yarnOfflineCache}
      fi
    '';

    # Simplified buildPhase to isolate the boolean issue
    buildPhase = ''
      set -x
      echo "DEBUG: rails-app build phase start" >&2
      export HOME=$PWD
      export source=$PWD
      
      echo "DEBUG: About to create vendor directory" >&2
      mkdir -p vendor/bundle/ruby/${rubyMajorMinor}.0
      echo "DEBUG: Created vendor directory successfully" >&2
      
      echo "DEBUG: About to copy gems" >&2
      echo "DEBUG: gems path is: ${gems}" >&2
      echo "DEBUG: rubyMajorMinor is: ${rubyMajorMinor}" >&2
      
      # Test if the issue is in this line
      cp -r ${gems}/lib/ruby/gems/${rubyMajorMinor}.0/* vendor/bundle/ruby/${rubyMajorMinor}.0/ || echo "Copy failed but continuing"
      
      echo "DEBUG: rails-app build phase done" >&2
    '';
    
    installPhase = ''
      echo "DEBUG: rails-app install phase start" >&2
      mkdir -p $out/app
      rsync -a --delete --include '.*' --exclude 'flake.nix' --exclude 'flake.lock' --exclude 'prepare-build.sh' . $out/app
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
  dockerImage = pkgs.writeText "docker-disabled" "Debug version - docker disabled";
}