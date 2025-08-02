{
  description = "Rails app template";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
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
    pkgs = import nixpkgs { inherit system overlays; config.permittedInsecurePackages = [ "openssl-1.1.1w" ]; };
    version = "2.0.97";
    detectRubyVersion = { src }: let
      rubyVersionFile = src + "/.ruby-version";
      gemfile = src + "/Gemfile";
      parseVersion = version: let
        trimmed = builtins.replaceStrings ["\n" "\r" " "] ["" "" ""] version;
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
    detectBundlerVersion = { src }: let
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
    rubyVersion = detectRubyVersion { src = ./.; };
    bundlerVersion = detectBundlerVersion { src = ./.; };
    buildConfig = {
      inherit rubyVersion;
      gccVersion = "latest";
      opensslVersion = "3";
    };
    railsBuild = rails-builder.lib.mkRailsBuild (buildConfig // { src = ./.; });
    rubyPackage = pkgs."ruby-${rubyVersion}";
    rubyVersionSplit = builtins.splitVersion rubyVersion;
    rubyMajorMinor = "${builtins.elemAt rubyVersionSplit 0}.${builtins.elemAt rubyVersionSplit 1}";
  in {
    apps.${system} = {
      detectBundlerVersion = {
        type = "app";
        program = "${pkgs.bash}/bin/bash";
        args = ["-c" "echo ${bundlerVersion}"];
      };
      detectRubyVersion = {
        type = "app";
        program = "${pkgs.bash}/bin/bash";
        args = ["-c" "echo ${rubyVersion}"];
      };
      flakeVersion = {
        type = "app";
        program = "${self.packages.${system}.flakeVersion}/bin/flake-version";
      };
    };
    devShells.${system} = {
      default = railsBuild.shell.overrideAttrs (old: {
        buildInputs = (old.buildInputs or []) ++ [rubyPackage];
        shellHook = ''
          unset RUBYLIB GEM_PATH
          export NIXPKGS_ALLOW_INSECURE=1
          echo "DEBUG: NIXPKGS_ALLOW_INSECURE=$NIXPKGS_ALLOW_INSECURE" >&2
          echo "DEBUG: Local nix.conf contents:" >&2
          cat /etc/nix/nix.conf 2>/dev/null || echo "DEBUG: /etc/nix/nix.conf not found" >&2
          export RAILS_ROOT=$(pwd)
          export GEM_HOME=$RAILS_ROOT/.nix-gems
          export GEM_PATH=$GEM_HOME:${rubyPackage}/lib/ruby/gems/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/${rubyMajorMinor}.0
          export RUBYLIB=${rubyPackage}/lib/ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/site_ruby/${rubyMajorMinor}.0
          export RUBYOPT=-I${rubyPackage}/lib/ruby/${rubyMajorMinor}.0
          export PATH=${rubyPackage}/bin:$GEM_HOME/bin:$HOME/.nix-profile/bin:$PATH
          echo "DEBUG: GEM_PATH=$GEM_PATH" >&2
          echo "DEBUG: RUBYLIB=$RUBYLIB" >&2
          echo "DEBUG: Checking for uri.rb in RUBYLIB paths:" >&2
          find ${rubyPackage}/lib/ruby -name uri.rb 2>/dev/null || echo "DEBUG: uri.rb not found" >&2
          mkdir -p $GEM_HOME
          gem install bundler:${bundlerVersion}
          if [ -f Gemfile ]; then
            bundle install --path $GEM_HOME
          fi
        '';
      });
      buildShell = railsBuild.shell.overrideAttrs (old: {
        buildInputs =
          (old.buildInputs or [])
          ++ [
            rubyPackage
            pkgs.rsync
            self.packages.${system}.manage-postgres
            self.packages.${system}.manage-redis
            self.packages.${system}.build-rails-app
          ];
        shellHook =
          old.shellHook
          + ''
            export BUNDLE_PATH=$source/vendor/bundle
            export BUNDLE_GEMFILE=$source/Gemfile
            export PATH=$BUNDLE_PATH/bin:~/.nix-profile/bin:$PATH
          '';
      });
    };
    packages.${system} = {
      app = railsBuild.app;
      buildApp = railsBuild.app;
      dockerImage = railsBuild.dockerImage;
      flakeVersion = pkgs.writeShellScriptBin "flake-version" ''
        #!${pkgs.runtimeShell}
        cat ${pkgs.writeText "flake-version" ''
          Frontend Flake Version: ${version}
          Backend Flake Version: ${rails-builder.lib.version or "2.0.25"}
        ''}
      '';
      manage-postgres = pkgs.writeShellScriptBin "manage-postgres" ''
        #!${pkgs.runtimeShell}
        set -e
        echo "DEBUG: Starting manage-postgres $1" >&2
        export source=$pwd
        export PGDATA=$source/tmp/pgdata
        export PGHOST=$source/tmp
        export PGDATABASE=rails_build
        mkdir -p "$PGDATA"
        case "$1" in
          start)
            echo "DEBUG: Checking PGDATA validity" >&2
            if [ -d "$PGDATA" ] && [ -f "$PGDATA/PG_VERSION" ]; then
              echo "DEBUG: Valid cluster found, checking status" >&2
              if ${pkgs.postgresql}/bin/pg_ctl -D "$PGDATA" status; then
                echo "PostgreSQL is already running."
                exit 0
              fi
            else
              echo "DEBUG: No valid cluster, initializing" >&2
              rm -rf "$PGDATA"
              mkdir -p "$PGDATA"
              echo "Running initdb..."
              if ! ${pkgs.postgresql}/bin/initdb -D "$PGDATA" --no-locale --encoding=UTF8 > $source/tmp/initdb.log 2>&1; then
                echo "initdb failed. Log:" >&2
                cat $source/tmp/initdb.log >&2
                exit 1
              fi
              echo "unix_socket_directories = '$PGHOST'" >> "$PGDATA/postgresql.conf"
            fi
            echo "Starting PostgreSQL..."
            if ! ${pkgs.postgresql}/bin/pg_ctl -D "$PGDATA" -l $source/tmp/pg.log -o "-k $PGHOST" start > $source/tmp/pg_ctl.log 2>&1; then
              echo "pg_ctl start failed. Log:" >&2
              cat $source/tmp/pg_ctl.log >&2
              exit 1
            fi
            sleep 2
            if ! ${pkgs.postgresql}/bin/pg_ctl -D "$PGDATA" status; then
              echo "PostgreSQL failed to start." >&2
              exit 1
            fi
            if ! ${pkgs.postgresql}/bin/psql -h "$PGHOST" -lqt | cut -d \| -f 1 | grep -qw "$PGDATABASE"; then
              ${pkgs.postgresql}/bin/createdb -h "$PGHOST" "$PGDATABASE"
            fi
            echo "PostgreSQL started successfully. DATABASE_URL: postgresql://postgres@localhost/$PGDATABASE?host=$PGHOST"
            ;;
          stop)
            echo "DEBUG: Stopping PostgreSQL" >&2
            if [ -d "$PGDATA" ] && ${pkgs.postgresql}/bin/pg_ctl -D "$PGDATA" status; then
              ${pkgs.postgresql}/bin/pg_ctl -D "$PGDATA" stop
              echo "PostgreSQL stopped."
            else
              echo "PostgreSQL is not running or PGDATA not found."
            fi
            ;;
          *)
            echo "Usage: manage-postgres {start|stop}" >&2
            exit 1
            ;;
        esac
        echo "DEBUG: manage-postgres completed" >&2
      '';
      manage-redis = pkgs.writeShellScriptBin "manage-redis" ''
        #!${pkgs.runtimeShell}
        export source=$PWD
        echo "DEBUG: Starting manage-redis $1" >&2
        echo "DEBUG: Source =  $source " >&2
        export REDIS_PID=$source/tmp/redis.pid
        case "$1" in
          start)
            if [ -f "$REDIS_PID" ] && kill -0 $(cat $REDIS_PID) 2>/dev/null; then
              echo "Redis is already running."
              exit 0
            fi
            mkdir -p $source
            ${pkgs.redis}/bin/redis-server --pidfile $REDIS_PID --daemonize yes --port 6379
            sleep 2
            if ! ${pkgs.redis}/bin/redis-cli ping | grep -q PONG; then
              echo "Failed to start Redis."
              exit 1
            fi
            echo "Redis started successfully. REDIS_URL: redis://localhost:6379/0"
            ;;
          stop)
            echo "DEBUG: Stopping Redis" >&2
            if [ -f "$REDIS_PID" ] && kill -0 $(cat $REDIS_PID) 2>/dev/null; then
              kill $(cat $REDIS_PID)
              rm -f $REDIS_PID
              echo "Redis stopped."
            else
              echo "Redis is not running or PID file not found."
            fi
            ;;
          *)
            echo "Usage: manage-redis {start|stop}" >&2
            exit 1
            ;;
        esac
        echo "DEBUG: manage-redis completed" >&2
      '';
      # In app template flake.nix
        build-rails-app = pkgs.writeShellScriptBin "build-rails-app" ''
          #!${pkgs.runtimeShell}
          set -e
          echo "DEBUG: Starting build-rails-app" >&2
          export BUNDLE_PATH=$PWD/vendor/bundle
          export BUNDLE_GEMFILE=$PWD/Gemfile
          export PATH=$BUNDLE_PATH/bin:${pkgs.bundler}/bin:${rubyPackage}/bin:$PATH
          export RAILS_ENV=production
          export SECRET_KEY_BASE=dummy_value_for_build
          export HOME=$PWD
          echo "DEBUG: BUNDLE_PATH=$BUNDLE_PATH" >&2
          echo "DEBUG: BUNDLE_GEMFILE=$BUNDLE_GEMFILE" >&2
          echo "DEBUG: PATH=$PATH" >&2
          echo "DEBUG: Gemfile exists: $([ -f "$BUNDLE_GEMFILE" ] && echo 'yes' || echo 'no')" >&2
          echo "DEBUG: Ruby version: $(ruby -v)" >&2
          echo "DEBUG: Bundler version: $(bundler -v)" >&2
          echo "DEBUG: Running bundle install..." >&2
          if ! bundler install --path $BUNDLE_PATH --binstubs $BUNDLE_PATH/bin; then
            echo "ERROR: bundle install failed" >&2
            exit 1
          fi
          echo "DEBUG: Patching shebangs in binstubs" >&2
          for bin in $BUNDLE_PATH/bin/*; do
            if [ -f "$bin" ]; then
              sed -i 's|#!/usr/bin/env ruby|#!/bin/env ruby|' "$bin"
              echo "DEBUG: Patched $bin" >&2
            fi
          done
          echo "DEBUG: Contents of $BUNDLE_PATH/bin:" >&2
          ls -l $BUNDLE_PATH/bin >&2
          echo "DEBUG: Contents of $BUNDLE_PATH:" >&2
          ls -lR $BUNDLE_PATH >&2
          echo "DEBUG: Running rails assets:precompile..." >&2
          bundler exec rails assets:precompile
          echo "Build complete. Outputs in $BUNDLE_PATH, public/packs." >&2
          echo "DEBUG: build-rails-app completed" >&2
      '';
    };
  };
}
