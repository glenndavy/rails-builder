{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
  };

  outputs = { self, nixpkgs, nixpkgs-ruby }:
  let
    forAllSystems = fn:
      nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ] (system: fn system);

    copyFiles = [
       "Gemfile"
       "Gemfile.lock"
       "vendor/cache"
       "app"
       "config"
       "public"
       "lib"
       "bin"
       "Rakefile"
    ];

    defaultBuildInputs = [
      nixpkgs.libyaml
      nixpkgs.postgresql
      nixpkgs.zlib
      nixpkgs.openssl
      nixpkgs.libxml2
      nixpkgs.libxslt2
      nixpkgs.imagemagick
    ];

    detectRubyVersion = { src, rubyVersionSpecified ? null }:
      let
        version = if rubyVersionSpecified != null
                  then rubyVersionSpecified
                  else if builtins.pathExists "${src}/.ruby_version"
                  then builtins.replaceStrings ["ruby" "ruby-"] ["" ""] (builtins.readFile "${src}/.ruby_version")
                  else throw "Missing .ruby_version file in ${src}. Please create it with the desired Ruby version.";
        underscored = builtins.replaceStrings ["."] ["_"] version;
      in
      {
        dotted = version;
        underscored = underscored;
      };
    detectBundlerVersion = { src }:
      if builtins.pathExists "${src}/Gemfile.lock"
      then let
        gemfileLock = builtins.readFile "${src}/Gemfile.lock";
        lines = builtins.split "\n" gemfileLock;
        lastLine = builtins.elemAt lines (builtins.length lines - 1);
        version = builtins.match ".*([0-9.]+).*" lastLine;
      in
        if version != null then builtins.head version
        else throw "Could not parse bundler_version from Gemfile.lock."
      else throw "Missing Gemfile.lock in ${src}.";

    buildRailsApp = {
      self,
      rubyVersionSpecified ? null,
      gemset ? null,
      src,
      railsEnv ? "production",
      extraEnv ? {},
      extraBuildInputs ? [],
      buildCommands ? [ "bundle exec rails assets:precompile" ],
      system
    }:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ nixpkgs-ruby.overlays.default ];
        };
        rubyVersion = detectRubyVersion {
          inherit src rubyVersionSpecified;
        };
        ruby = pkgs."ruby-${rubyVersion.underscored}";
      in
      pkgs.stdenv.mkDerivation {
        name = "rails-app";
        inherit src extraBuildInputs;
        buildInputs = [ ruby ] ++ defaultBuildInputs ++ extraBuildInputs;
        nativeBuildInputs = [ ruby ] ++ (if gemset != null then [ ruby.gems ] else []);
        buildPhase = ''
          export APP_DIR=$TMPDIR/app
          mkdir -p $APP_DIR
          # Copy specific files
          echo "Copying files to $APP_DIR:"
          # Note: copyFiles is undefined; define it or replace with actual files
          # ${builtins.concatStringsSep "\n" (map (file: ''
          #   if [ -e "${file}" ]; then
          #     echo "Copying ${file}"
          #     cp -r --parents "${file}" $APP_DIR
          #   else
          #     echo "Skipping ${file} (not found)"
          #   fi
          # '') copyFiles)}
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
          ${if railsEnv == "production" then "bundle config set --local without 'development test'" else ""}
          ${if gemset != null then ''
            # Use gemset.nix for gems
            bundle config set --local path $out/gems
            bundle install
          '' else ''
            # Use vendored gems
            bundle config set --local path vendor/bundle
            bundle install
          ''}
          # Run build commands
          # Note: buildCommands is undefined; define it or replace with actual commands
          # ${builtins.concatStringsSep "\n" buildCommands}
          # Stop PostgreSQL
          pg_ctl -D $PGDATA stop
        '';
        installPhase = ''
          mkdir -p $out/app
          cp -r $APP_DIR/. $out/app
          cat > $out/bin/run-rails <<EOF
          #!${pkgs.bash}/bin/bash
          export PATH=$out/app/vendor/bundle/ruby/${rubyVersion.dotted}/bin:\$PATH
          export RAILS_ENV=production
          export RAILS_SERVE_STATIC_FILES=true
          cd $out/app
          bundle exec puma -C config/puma.rb
          EOF
          chmod +x $out/bin/run-rails
        '';
      };

    dockerImage = {
      system,
      railsApp,
      dockerCmd,
      extraEnv ? [],
      debug ? false,
    }:
      let
        pkgs = import nixpkgs { inherit system; };
        basePaths = [
          railsApp
          railsApp.buildInputs
          pkgs.bash
        ] ++ defaultBuildInputs;
        debugPaths = [
          pkgs.coreutils
          pkgs.findutils
          pkgs.htop
          pkgs.agrep
          pkgs.busybox
          pkgs.less
        ];
        #? [ "/app/vendor/bundle/ruby/${rubyVersion.dotted}/bin/bundle" "exec" "puma" "-C" "/app/config/puma.rb" ],
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

    devShells = forAllSystems (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ nixpkgs-ruby.overlays.default ];
        };
      in
      {
        bundix = pkgs.mkShell {
          buildInputs = [ pkgs.bundix ];
          shellHook = ''
            echo "Run 'bundix --local' to generate gemset.nix, or use 'nix run .#generate-gemset'."
          '';
        };
        default = let
          ruby_version = detectRubyVersion { src = ./.; };
          ruby = pkgs."ruby-${ruby_version.underscored}";
          bundler_version = detectBundlerVersion { src = ./.; };
          bundler = pkgs.stdenv.mkDerivation {
            name = "bundler-${bundler_version}";
            buildInputs = [ ruby ];
            dontUnpack = true;
            installPhase = ''
              export HOME=$TMPDIR
              export GEM_HOME=$out/bundler_gems
              export TMP_BIN=$TMPDIR/bin
              mkdir -p $HOME $GEM_HOME $TMP_BIN
              gem install --no-document --local ${./vendor/cache + "/bundler-${bundler_version}.gem"} --install-dir $GEM_HOME --bindir $TMP_BIN
              mkdir -p $out/bin
              cp -r $TMP_BIN/* $out/bin/
            '';
          };
        in
        pkgs.mkShell {
          buildInputs = [ ruby pkgs.bundix pkgs.libyaml pkgs.postgresql pkgs.zlib pkgs.openssl ];
          shellHook = ''
            export PATH=${bundler}/bin:$PWD/vendor/bundle/ruby/${ruby_version.dotted}/bin:$PATH
            export HOME=$TMPDIR
            export GEM_HOME=$TMPDIR/gems
            export GEM_PATH=${bundler}/bundler_gems:$GEM_HOME:$PWD/vendor/bundle/ruby/${ruby_version.dotted}
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
  in
  {
    lib = {
      inherit buildRailsApp detectRubyVersion detectBundlerVersion dockerImage;
    };
    devShells = forAllSystems (system: devShells.${system});
    packages = forAllSystems (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ nixpkgs-ruby.overlays.default ];
        };
      in
      {
        generate-gemset = pkgs.writeFile {
          name = "generate-gemset";
          executable = true;
          destination = "/bin/generate-gemset";
          text = ''
            #!/bin/bash
            if [ ! -f Gemfile.lock ]; then
              echo "Error: Gemfile.lock is missing."
              exit 1
            fi
            if [ ! -d vendor/cache ]; then
              echo "Error: vendor/cache is missing."
              exit 1
            fi
            ${pkgs.bundix}/bin/bundix --local
            if [ ! -f gemset.nix ]; then
              echo "Error: Failed to generate gemset.nix."
              exit 1
            fi
            echo "Generated gemset.nix successfully."
          '';
        };
      });
    nixosModule = { railsApp, ... }: {
      imports = [ ./nixos-module.nix ];
      config.deployment.railsApp = railsApp;
    };
  };
}
