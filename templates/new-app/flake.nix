{
  description = "Rails app template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rails-builder.url = "github:glenndavy/rails-builder";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
  };

  outputs = {
    self,
    nixpkgs,
    rails-builder,
    nixpkgs-ruby,
    flake-compat,
    ...
  }: let
    system = "x86_64-linux";
    overlays = [nixpkgs-ruby.overlays.default];
    pkgs = import nixpkgs {inherit system overlays;};
    version = "2.0.29"; # Frontend version

    # Detect Ruby version
    detectRubyVersion = {src}: let
      rubyVersionFile = src + "/.ruby-version";
      gemfile = src + "/Gemfile";
      parseVersion = version: let
        trimmed = builtins.replaceStrings ["\n" "\r" " "] ["" "" ""] version; # Remove newlines and spaces
        cleaned = builtins.replaceStrings ["ruby-" "ruby"] ["" ""] trimmed;
      in
        builtins.match "^([0-9]+\\.[0-9]+\\.[0-9]+)$" cleaned;
      fromRubyVersion =
        if builtins.pathExists rubyVersionFile
        then let
          version = builtins.readFile rubyVersionFile;
        in
          if parseVersion version != null
          then builtins.head (parseVersion version)
          else throw "Error: Invalid Ruby version in .ruby-version: ${version}"
        else throw "Error: No .ruby-version found in RAILS_ROOT";
      fromGemfile =
        if builtins.pathExists gemfile
        then let
          content = builtins.readFile gemfile;
          match = builtins.match ".*ruby ['\"]([0-9]+\\.[0-9]+\\.[0-9]+)['\"].*" content;
        in
          if match != null
          then builtins.head match
          else fromRubyVersion
        else fromRubyVersion;
    in
      fromGemfile;

    # Detect Bundler version
    detectBundlerVersion = {src}: let
      gemfileLock = src + "/Gemfile.lock";
      gemfile = src + "/Gemfile";
      parseVersion = version: builtins.match "([0-9]+\\.[0-9]+\\.[0-9]+)" version;
      fromGemfileLock =
        if builtins.pathExists gemfileLock
        then let
          content = builtins.readFile gemfileLock;
          match = builtins.match ".*BUNDLED WITH\n   ([0-9.]+).*" content;
        in
          if match != null && parseVersion (builtins.head match) != null
          then builtins.head match
          else throw "Error: Invalid or missing Bundler version in Gemfile.lock"
        else throw "Error: No Gemfile.lock found";
      fromGemfile =
        if builtins.pathExists gemfile
        then let
          content = builtins.readFile gemfile;
          match = builtins.match ".*gem ['\"]bundler['\"], ['\"](~> )?([0-9.]+)['\"].*" content;
        in
          if match != null && parseVersion (builtins.elemAt match 1) != null
          then builtins.elemAt match 1
          else fromGemfileLock
        else fromGemfileLock;
    in
      fromGemfile;

    rubyVersion = detectRubyVersion {src = ./.;};
    bundlerVersion = detectBundlerVersion {src = ./.;};

    # App-specific customizations
    buildConfig = {
      inherit rubyVersion;
      bundlerVersion = bundlerVersion;
      gccVersion = "latest";
      opensslVersion = "3"; # Use valid OpenSSL version
    };

    # Call backend builder
    railsBuild = rails-builder.lib.mkRailsBuild buildConfig;
    rubyPackage = pkgs."ruby-${rubyVersion}";
    bundlerPackage = pkgs.bundler; # Use default bundler version
  in {
    devShells.${system}.buildShell = railsBuild.shell.overrideAttrs (old: {
      buildInputs =
        old.buildInputs
        ++ [
          pkgs.rsync
          self.packages.${system}.manage-postgres
          self.packages.${system}.manage-redis
          self.packages.${system}.build-rails-app
        ];
      shellHook =
        old.shellHook
        + ''
          export BUNDLE_PATH=/builder/.bundle
          export BUNDLE_GEMFILE=/builder/Gemfile
        '';
    });
    packages.${system} = {
      buildApp = railsBuild.app;
      dockerImage = railsBuild.dockerImage;
      flakeVersion = pkgs.writeShellScriptBin "flake-version" ''
        #!${pkgs.runtimeShell}
        cat ${pkgs.writeText "flake-version" ''
          Frontend Flake Version: ${version}
          Backend Flake Version: ${rails-builder.lib.version or "2.0.15"}
        ''}
      '';
      manage-postgres = pkgs.writeShellScriptBin "manage-postgres" ''
        #!${pkgs.runtimeShell}
        set -e
        export PGDATA=/builder/pgdata
        export PGHOST=/builder
        export PGDATABASE=rails_build
        # Ensure PGDATA and PGHOST are writable
        mkdir -p $PGDATA
        chmod 700 $PGDATA
        chmod 700 /builder
        case "$1" in
          start)
            # Check if PGDATA is a valid database cluster
            if [ -d "$PGDATA" ] && [ -f "$PGDATA/PG_VERSION" ]; then
              if ${pkgs.postgresql}/bin/pg_ctl -D $PGDATA status; then
                echo "PostgreSQL is already running."
                exit 0
              fi
            else
              rm -rf $PGDATA # Remove invalid directory
              mkdir -p $PGDATA
              chmod 700 $PGDATA
              echo "Running initdb..."
              if ! ${pkgs.postgresql}/bin/initdb -D $PGDATA --no-locale --encoding=UTF8 > /builder/initdb.log 2>&1; then
                echo "initdb failed. Log:"
                cat /builder/initdb.log
                exit 1
              fi
              echo "unix_socket_directories = '$PGHOST'" >> $PGDATA/postgresql.conf
            fi
            echo "Starting PostgreSQL..."
            if ! ${pkgs.postgresql}/bin/pg_ctl -D $PGDATA -l /builder/pg.log -o "-k $PGHOST" start > /builder/pg_ctl.log 2>&1; then
              echo "pg_ctl start failed. Log:"
              cat /builder/pg_ctl.log
              exit 1
            fi
            sleep 2
            if ! ${pkgs.postgresql}/bin/pg_ctl -D $PGDATA status; then
              echo "PostgreSQL failed to start."
              exit 1
            fi
            if ! ${pkgs.postgresql}/bin/psql -h $PGHOST -lqt | cut -d \| -f 1 | grep -qw $PGDATABASE; then
              ${pkgs.postgresql}/bin/createdb -h $PGHOST $PGDATABASE
            fi
            echo "PostgreSQL started successfully. DATABASE_URL: postgresql://postgres@localhost/$PGDATABASE?host=$PGHOST"
            ;;
          stop)
            if [ -d "$PGDATA" ] && ${pkgs.postgresql}/bin/pg_ctl -D $PGDATA status; then
              ${pkgs.postgresql}/bin/pg_ctl -D $PGDATA stop
              echo "PostgreSQL stopped."
            else
              echo "PostgreSQL is not running or PGDATA not found."
            fi
            ;;
          *)
            echo "Usage: manage-postgres {start|stop}"
            exit 1
            ;;
        esac
      '';
      manage-redis = pkgs.writeShellScriptBin "manage-redis" ''
        #!${pkgs.runtimeShell}
        set -e
        export REDIS_SOCKET=/builder/redis.sock
        export REDIS_PID=/builder/redis.pid
        case "$1" in
          start)
            if [ -f "$REDIS_PID" ] && kill -0 $(cat $REDIS_PID) 2>/dev/null; then
              echo "Redis is already running."
              exit 0
            fi
            mkdir -p /builder
            ${pkgs.redis}/bin/redis-server --unixsocket $REDIS_SOCKET --pidfile $REDIS_PID --daemonize yes --port 6379
            sleep 2
            if ! ${pkgs.redis}/bin/redis-cli -s $REDIS_SOCKET ping | grep -q PONG; then
              echo "Failed to start Redis."
              exit 1
            fi
            echo "Redis started successfully. REDIS_URL: redis://localhost:6379/0"
            ;;
          stop)
            if [ -f "$REDIS_PID" ] && kill -0 $(cat $REDIS_PID) 2>/dev/null; then
              kill $(cat $REDIS_PID)
              rm -f $REDIS_PID
              echo "Redis stopped."
            else
              echo "Redis is not running or PID file not found."
            fi
            ;;
          *)
            echo "Usage: manage-redis {start|stop}"
            exit 1
            ;;
        esac
      '';
      build-rails-app = pkgs.writeShellScriptBin "build-rails-app" ''
        #!${pkgs.runtimeShell}
        set -e
        export BUNDLE_PATH=/builder/vendor/bundle
        export BUNDLE_GEMFILE=/builder/Gemfile
        export PATH=$BUNDLE_PATH/bin:$PATH
        echo "build-rails-app (Flake Version: ${version})"
        echo "Ruby version: $(${rubyPackage}/bin/ruby -v)"
        echo "Bundler version: $(${pkgs.bundler}/bin/bundler -v)"
        echo "Running bundle install..."
        ${pkgs.bundler}/bin/bundle install --path $BUNDLE_PATH --binstubs $BUNDLE_PATH/bin
        echo "Running rails assets:precompile..."
        ${pkgs.bundler}/bin/bundle exec rails assets:precompile
        echo "Build complete. Outputs in $BUNDLE_PATH, public/packs."
      '';
    };
    apps.${system}.flakeVersion = {
      type = "app";
      program = "${self.packages.${system}.flakeVersion}/bin/flake-version";
    };
  };
}
