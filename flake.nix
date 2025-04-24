{
  description = "Rails app builder flake for multiple apps";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
  };

  outputs = { self, nixpkgs, nixpkgs-ruby }: let
    forAllSystems = f: nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ] (system: f system);
  in {
    lib = {
      buildRailsApp = { 
        system, 
        rubyVersion, 
        src, 
        gems, 
        railsEnv ? "production", 
        extraEnv ? {}, 
        buildCommands ? [ "bundle exec rails assets:precompile" ],
        extraBuildInputs ? [],
        copyFiles ? [
          "Gemfile"
          "Gemfile.lock"
          "vendor/cache"
          "app"
          "config"
          "public"
          "lib"
          "bin"
          "Rakefile"
        ]
      }: 
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ nixpkgs-ruby.overlays.default ];
          };
          rubyVersionDotted = builtins.replaceStrings ["_"] ["."] rubyVersion;
          ruby = pkgs."ruby-${rubyVersionDotted}";
          bundlerGem = pkgs.fetchurl {
            url = "https://rubygems.org/downloads/bundler-2.6.8.gem";
            sha256 = "sha256-vemZkXKWoWLklWSULcIxLtmo0y/C97SWyV9t88/Mh6k=";
          };
          bundler = pkgs.stdenv.mkDerivation {
            name = "bundler-2.6.8";
            buildInputs = [ ruby ];
            dontUnpack = true;
            installPhase = ''
              export HOME=$TMPDIR
              export GEM_HOME=$out/bundler_gems
              export TMP_BIN=$TMPDIR/bin
              mkdir -p $HOME $GEM_HOME $TMP_BIN
              gem install --no-document --local ${bundlerGem} --install-dir $GEM_HOME --bindir $TMP_BIN
              mkdir -p $out/bin
              cp -r $TMP_BIN/* $out/bin/
            '';
          };
        in
        pkgs.stdenv.mkDerivation {
          name = "rails-app";
          inherit src;
          buildInputs = [ ruby bundler pkgs.libyaml pkgs.postgresql pkgs.zlib pkgs.openssl ] ++ extraBuildInputs;
          buildPhase = ''
            echo "***** BUILDER VERSION 0.31 *******************"
            # Validate extraEnv
            ${if !builtins.isAttrs extraEnv then "echo 'ERROR: extraEnv must be a set, got ${builtins.typeOf extraEnv}' >&2; exit 1" else ""}
            # Validate buildCommands
            ${if !builtins.isList buildCommands then "echo 'ERROR: buildCommands must be a list, got ${builtins.typeOf buildCommands}' >&2; exit 1" else ""}
            # Set up app directory
            export APP_DIR=$TMPDIR/app
            mkdir -p $APP_DIR
            # Copy specific files
            echo "Copying files to $APP_DIR:"
            ${builtins.concatStringsSep "\n" (map (file: ''
              if [ -e "${file}" ]; then
                echo "Copying ${file}"
                cp -r --parents "${file}" $APP_DIR
              else
                echo "Skipping ${file} (not found)"
              fi
            '') copyFiles)}
            # Set up PostgreSQL
            export PGDATA=$TMPDIR/pgdata
            export PGHOST=$TMPDIR
            export PGUSER=postgres
            export PGDATABASE=rails_build
            mkdir -p $PGDATA
            initdb -D $PGDATA --no-locale --encoding=UTF8 --username=$PGUSER
            echo "unix_socket_directories = '$TMPDIR'" >> $PGDATA/postgresql.conf
            pg_ctl -D $PGDATA -l $TMPDIR/pg.log -o "-k $TMPDIR" start
            sleep 2
            createdb -h $TMPDIR $PGDATABASE
            export DATABASE_URL="postgresql://$PGUSER@localhost/$PGDATABASE?host=$TMPDIR"
            # Set up environment
            export RAILS_ENV=${railsEnv}
            ${if railsEnv == "production" then "export RAILS_SERVE_STATIC_FILES=true" else ""}
            ${builtins.concatStringsSep "\n" (builtins.attrValues (builtins.mapAttrs (name: value: "export ${name}=${pkgs.lib.escapeShellArg value}") extraEnv))}
            # Skip credentials for build
            mkdir -p $APP_DIR/config/initializers
            cat > $APP_DIR/config/initializers/build.rb <<EOF
            Rails.configuration.require_master_key = false if Rails.env.production?
            EOF
            # Configure Bundler
            cd $APP_DIR
            bundle config set --local path 'vendor/bundle'
            bundle config set --local bin 'vendor/bundle/ruby/3.2.0/bin'
            bundle config set --local gemfile Gemfile
            ${if railsEnv == "production" then "bundle config set --local without 'development test'" else ""}
            # Run bundle install
            echo "Running bundle install:"
            bundle install --local --path vendor/bundle --verbose > bundle_install.log 2>&1 || (cat bundle_install.log; exit 1)
            # Ensure bin permissions
            chmod -R u+x $APP_DIR/vendor/bundle/ruby/3.2.0/bin
            # Run build commands
            ${builtins.concatStringsSep "\n" buildCommands}
            # Stop PostgreSQL
            pg_ctl -D $PGDATA stop
          '';
          installPhase = ''
            mkdir -p $out/app
            cp -r $APP_DIR/. $out/app
            mkdir -p $out/bin
            cat > $out/bin/run-rails <<EOF
            #!${pkgs.bash}/bin/bash
            export PATH=$out/app/vendor/bundle/ruby/3.2.0/bin:\$PATH
            export RAILS_ENV=production
            export RAILS_SERVE_STATIC_FILES=true
            cd $out/app
            bundle exec puma -C config/puma.rb
            EOF
            chmod +x $out/bin/run-rails
          '';
        };

      nixosModule = { railsApp, ... }: {
        imports = [ ./nixos-module.nix ];
        config.deployment.railsApp = railsApp;
      };

      dockerImage = { 
        system, 
        railsApp, 
        dockerCmd ? [ "/app/vendor/bundle/ruby/3.2.0/bin/bundle" "exec" "puma" "-C" "/app/config/puma.rb" ], 
        extraEnv ? [],
        debug ? false
      }: 
        let
          pkgs = import nixpkgs { inherit system; };
          basePaths = [
            railsApp
            pkgs.bash
            pkgs.ruby_3_2
            pkgs.libyaml
            pkgs.zlib
            pkgs.openssl
          ];
          debugPaths = [
            pkgs.coreutils
            pkgs.findutils
            pkgs.grep
            pkgs.less
          ];
        in
        pkgs.dockerTools.buildImage {
          name = if debug then "rails-app-debug" else "rails-app";
          tag = "latest";
          copyToRoot = pkgs.buildEnv {
            name = "image-root";
            paths = basePaths ++ (if debug then debugPaths else []);
            pathsToLink = [ "/bin" "/app" ];
          };
          config = {
            Cmd = dockerCmd;
            WorkingDir = "/app";
            ExposedPorts = { "3000/tcp" = {}; };
            Env = [
              "RAILS_ENV=production"
              "RAILS_SERVE_STATIC_FILES=true"
              "DATABASE_URL=postgresql://postgres@localhost/rails_production?host=/var/run/postgresql"
            ] ++ extraEnv;
          };
        };
    };

    devShells = forAllSystems (system: {
      default = let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ nixpkgs-ruby.overlays.default ];
        };
        ruby = pkgs."ruby-3.2.6";
        bundler = pkgs.stdenv.mkDerivation {
          name = "bundler-2.6.8";
          buildInputs = [ ruby ];
          dontUnpack = true;
          installPhase = ''
            export HOME=$TMPDIR
            export GEM_HOME=$out/bundler_gems
            export TMP_BIN=$TMPDIR/bin
            mkdir -p $HOME $GEM_HOME $TMP_BIN
            gem install --no-document --local ${pkgs.fetchurl {
              url = "https://rubygems.org/downloads/bundler-2.6.8.gem";
              sha256 = "sha256-vemZkXKWoWLklWSULcIxLtmo0y/C97SWyV9t88/Mh6k=";
            }} --install-dir $GEM_HOME --bindir $TMP_BIN
            mkdir -p $out/bin
            cp -r $TMP_BIN/* $out/bin/
          '';
        };
      in pkgs.mkShell {
        buildInputs = [ ruby bundler pkgs.libyaml pkgs.postgresql pkgs.zlib pkgs.openssl ];
        shellHook = ''
          export PATH=${bundler}/bin:$PWD/vendor/bundle/ruby/3.2.0/bin:$PATH
          export HOME=$TMPDIR
          export GEM_HOME=$TMPDIR/gems
          export GEM_PATH=${bundler}/bundler_gems:$GEM_HOME:$PWD/vendor/bundle/ruby/3.2.0
          export BUNDLE_PATH=$PWD/vendor/bundle
          export BUNDLE_USER_HOME=$TMPDIR/.bundle
          export BUNDLE_USER_CACHE=$TMPDIR/.bundle/cache
          mkdir -p $HOME $GEM_HOME $BUNDLE_PATH $BUNDLE_USER_HOME $BUNDLE_USER_CACHE
          chmod -R u+w $BUNDLE_PATH $BUNDLE_USER_HOME $BUNDLE_USER_CACHE
          echo "TMPDIR: $TMPDIR"
          echo "PWD: $PWD"
          echo "RAILS_ENV is unset by default. Set it with: export RAILS_ENV=<production|development|test>"
          echo "Example: export RAILS_ENV=development; bundle install; bundle exec rails server"
          echo "Vendored gems required in vendor/cache. Run 'bundle package' to populate."
        '';
      };
    });
  };
}
