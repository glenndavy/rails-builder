{
  description = "Rails app builder flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
  };

  outputs = { self, nixpkgs, nixpkgs-ruby }: let
    forAllSystems = f: nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ] (system: f system);
  in {
    lib = {
      buildRailsApp = { system, rubyVersion, src, gems, railsEnv ? "production" }: 
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ nixpkgs-ruby.overlays.default ];
          };
          rubyVersionDotted = builtins.replaceStrings ["_"] ["."] rubyVersion;
          ruby = pkgs."ruby-${rubyVersionDotted}";
          # Pre-fetch Bundler 2.6.8
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
          buildInputs = [ ruby bundler pkgs.libyaml pkgs.postgresql pkgs.zlib pkgs.openssl ];
          buildPhase = ''
            echo "***** BUILDER VERSION 0.8 *******************"
            # Debug paths
            echo "TMPDIR: $TMPDIR"
            echo "PWD: $PWD"
            echo "APP_DIR: $TMPDIR/app"
            # Set up app directory
            export APP_DIR=$TMPDIR/app
            mkdir -p $APP_DIR
            cp -r $PWD/. $APP_DIR
            # Debug vendor/cache
            echo "Checking vendor/cache in $APP_DIR:"
            ls -l $APP_DIR/vendor/cache | grep -E "rails-8.0.2|propshaft-1.1.0|debug" || echo "Missing gems in vendor/cache"
            # Set up environment
            export RAILS_ENV=${railsEnv}
            export PATH=${bundler}/bin:$APP_DIR/vendor/bundle/ruby/3.2.0/bin:$PATH
            export HOME=$TMPDIR
            export GEM_HOME=$TMPDIR/gems
            export GEM_PATH=${bundler}/bundler_gems:$GEM_HOME:$APP_DIR/vendor/bundle/ruby/3.2.0
            export BUNDLE_PATH=$APP_DIR/vendor/bundle
            export BUNDLE_USER_HOME=$TMPDIR/.bundle
            export BUNDLE_USER_CACHE=$TMPDIR/.bundle/cache
            mkdir -p $HOME $GEM_HOME $BUNDLE_PATH $BUNDLE_USER_HOME $BUNDLE_USER_CACHE
            chmod -R u+w $APP_DIR $BUNDLE_PATH $BUNDLE_USER_HOME $BUNDLE_USER_CACHE
            # Debug environment
            echo "Bundler version:"
            bundle --version
            echo "RAILS_ENV: $RAILS_ENV"
            echo "PATH: $PATH"
            echo "GEM_PATH: $GEM_PATH"
            echo "Rails executable:"
            command -v rails || echo "rails not found"
            # Configure Bundler
            cd $APP_DIR
            bundle config set --local path 'vendor/bundle'
            bundle config set --local bin 'vendor/bundle/ruby/3.2.0/bin'
            bundle config set --local gemfile Gemfile
            bundle config set --local without 'development test'
            # Run bundle install
            echo "Running bundle install:"
            bundle install --local --path vendor/bundle --verbose > bundle_install.log 2>&1 || (cat bundle_install.log; exit 1)
            # Debug installed gems and bin
            echo "Installed gems:"
            ls -l vendor/bundle/ruby/3.2.0/gems | grep -E "rails-8.0.2|propshaft-1.1.0|debug" || echo "No matching gems installed"
            echo "Checking debug gem files:"
            ls -l vendor/bundle/ruby/3.2.0/gems/debug-*/lib/debug | grep prelude || echo "No debug/prelude.rb found"
            echo "Bin directory:"
            ls -l vendor/bundle/ruby/3.2.0/bin | grep rails || echo "No rails executable"
            # Ensure bin permissions
            chmod -R u+x $APP_DIR/vendor/bundle/ruby/3.2.0/bin
            # Run rails
            bundle exec rails assets:precompile
          '';
          installPhase = ''
            mkdir -p $out/app
            cp -r $APP_DIR/. $out/app
          '';
        };

      nixosModule = { railsApp, ... }: {
        imports = [ ./nixos-module.nix ];
        config.deployment.railsApp = railsApp;
      };

      dockerImage = { system, railsApp }: 
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.dockerTools.buildImage {
          name = "rails-app";
          tag = "latest";
          contents = [ railsApp ];
          config = {
            Cmd = [ "/app/vendor/bundle/ruby/3.2.0/bin/bundle" "exec" "puma" "-C" "/app/config/puma.rb" ];
            WorkingDir = "/app";
            ExposedPorts = { "3000/tcp" = {}; };
          };
        };
    };

    # Development shell for testing different RAILS_ENV
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
        '';
      };
    });
  };
}
