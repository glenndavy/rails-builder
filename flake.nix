mkDockerImage = {
  railsApp,
  name,
  debug ? false,
  extraEnv ? [],
  ruby, # Use ruby parameter from buildRailsApp
  bundler, # Use bundler from buildRailsApp
}: let
  startScript = pkgs.writeShellScript "start" ''
    #!/bin/bash
    set -e
    # ... Procfile and EXECUTION_ROLE logic ...
  '';
  basePaths = [
    railsApp # Includes the bundix-based railsApp
    railsApp.buildInputs
    pkgs.bash
    pkgs.postgresql # Ensure libpq.so.5
  ];
  debugPaths = [
    pkgs.coreutils
    pkgs.findutils
    pkgs.htop
    pkgs.agrep
    pkgs.busybox
    pkgs.less
  ];
  # Derive rubyVersion from ruby derivation name
  rubyVersion = let
    match = builtins.match "ruby-([0-9.]+)" ruby.name;
  in {
    dotted = if match != null then builtins.head match else throw "Cannot derive Ruby version from ${ruby.name}";
    underscored = builtins.replaceStrings ["."] ["_"] (if match != null then builtins.head match else throw "Cannot derive Ruby version from ${ruby.name}");
  };
in
  pkgs.dockerTools.buildImage {
    name = if debug then "${name}-debug" else name;
    tag = "latest";
    copyToRoot = pkgs.buildEnv {
      name = "image-root";
      paths = basePaths ++ (if debug then debugPaths else []);
      pathsToLink = ["/app" "/bin" "/lib"];
    };
    config = {
      Entrypoint = ["/bin/start"];
      WorkingDir = "/app";
      Env = [
        "PATH=/app/vendor/bundle/bin:/bin"
        "GEM_HOME=/app/.nix-gems"
        "BUNDLE_PATH=/app/vendor/bundle"
        "BUNDLE_GEMFILE=/app/Gemfile"
        "BUNDLE_USER_CONFIG=/app/.bundle/config"
        "RAILS_ENV=production"
        "RAILS_SERVE_STATIC_FILES=true"
        "DATABASE_URL=postgresql://postgres@localhost/rails_production?host=/var/run/postgresql"
        "RUBYLIB=${ruby}/lib/ruby/${rubyVersion.dotted}"
        "RUBYOPT=-r logger"
        "LD_LIBRARY_PATH=/lib:$LD_LIBRARY_PATH"
      ] ++ extraEnv;
      ExposedPorts = {
        "3000/tcp" = {};
      };
    };
  };
