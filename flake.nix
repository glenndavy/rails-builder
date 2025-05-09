{
  description = "Reusable Rails builder for Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-ruby,
  }: let
    system = "x86_64-linux";
    nixpkgsConfig = {
      permittedInsecurePackages = [
        "openssl-1.1.1w"
        "openssl_1_1_1w"
        "openssl-1.1.1"
        "openssl_1_1"
      ];
    };
    pkgs = import nixpkgs {
      inherit system;
      config = nixpkgsConfig;
      overlays = [nixpkgs-ruby.overlays.default];
    };
    flake_version = "26"; # Incremented to 26
    bundlerGems = import ./bundler-hashes.nix;

    detectRubyVersion = {
      src,
      rubyVersionSpecified ? null,
    }: let
      version =
        if rubyVersionSpecified != null
        then rubyVersionSpecified
        else if builtins.pathExists "${src}/.ruby-version"
        then builtins.replaceStrings ["ruby" "-" "\n" "\r"] ["" "" "" ""] (builtins.readFile "${src}/.ruby-version")
        else throw "Missing .ruby-version file in ${src}.";
      underscored = builtins.replaceStrings ["."] ["_"] version;
    in {
      dotted = fd version;
      underscored = underscored;
    };

    detectBundlerVersion = {
      src,
      defaultVersion ? "2.6.8",
    }: let
      lockFile = "${src}/Gemfile.lock";
      fileExists = builtins.pathExists lockFile;
      version =
        if fileExists
        then let
          rawContent = builtins.readFile lockFile;
          allLines = builtins.split "\n" rawContent;
          lines = builtins.filter (line: builtins.typeOf line == "string" && line != "") allLines;
          lineCount = builtins.length lines;
          bundledWithIndices = builtins.filter (i: (builtins.match "[[:space:]]*BUNDLED WITH[[:space:]]*" (builtins.elemAt lines i)) != null) (builtins.genList (i: i) lineCount);
          versionLine =
            if bundledWithIndices != [] && (builtins.head bundledWithIndices) + 1 < lineCount
            then let
              idx = (builtins.head bundledWithIndices) + 1;
              line = builtins.elemAt lines idx;
              lineType = builtins.typeOf line;
            in
              if lineType == "string"
              then line
              else throw "Version line is not a string: type is ${lineType}, value is ${toString line}"
            else throw "BUNDLED WITH not found or no version line follows in Gemfile.lock.";
          versionMatch = builtins.match "[[:space:]]*([0-9]+\\.[0-9]+\\.[0-9]+(\\.[0-9]+)?)[[:space:]]*" versionLine;
        in
          if versionMatch != null
          then builtins.head versionMatch
          else throw "Could not parse bundler_version from line after BUNDLED WITH: '${versionLine}'"
        else defaultVersion;
    in
      version;

    buildRailsApp = {
      system ? "x86_64-linux",
      rubyVersionSpecified ? null,
      gemset ? null,
      src,
      railsEnv ? "production",
      extraEnv ? {},
      extraBuildInputs ? [],
      gem_strategy ? "vendored",
      buildCommands ? null,
      nixpkgsConfig,
      bundlerHashes ? ./bundler-hashes.nix,
      defaultBundlerVersion ? "2.6.8",
    }: let
      pkgs = import nixpkgs {
        inherit system;
        config = nixpkgsConfig;
        overlays = [nixpkgs-ruby.overlays.default];
      };
      bundlerGems = import bundlerHashes;
      defaultBuildInputs = with pkgs; [libyaml postgresql zlib openssl libxml2 libxslt imagemagick nodejs_20];
      rubyVersion = detectRubyVersion {inherit src rubyVersionSpecified;};
      ruby = pkgs."ruby-${rubyVersion.dotted}";
      bundlerVersion = detectBundlerVersion {
        inherit src;
        defaultVersion = defaultBundlerVersion;
      };
      bundlerGem = bundlerGems."${bundlerVersion}" or (throw "Unsupported bundler version: ${bundlerVersion}. Update bundler-hashes.nix in rails-builder or provide a custom bundlerHashes.");
      bundler = pkgs.stdenv.mkDerivation {
        name = "bundler-${bundlerVersion}";
        buildInputs = [ruby];
        src = pkgs.fetchurl {
          url = bundlerGem.url;
          sha256 = bundlerGem.sha256;
        };
        dontUnpack = true;
        installPhase = ''
          export HOME=$TMPDIR
          export GEM_HOME=$out/lib/ruby/gems/${rubyVersion.dotted}
          export GEM_PATH=$GEM_HOME
          export PATH=$out/bin:$PATH
          mkdir -p $GEM_HOME $out/bin
          gem install --no-document --local $src --install-dir $GEM_HOME --bindir $out/bin
          if [ -f "$out/bin/bundle" ]; then
            echo "Bundler executable found"
          else
            echo "Bundler executable not found"
            exit 1
          fi
        '';
      };
      effectiveBuildCommands =
        if buildCommands == null
        then ["${bundler}/bin/bundle exec $out/app/vendor/bundle/bin/rails assets:precompile"]
        else if builtins.isList buildCommands
        then buildCommands
        else [buildCommands];
    in {
      app = pkgs.stdenv.mkDerivation {
        name = "rails-app";
        inherit src extraBuildInputs;
        buildInputs = [ruby bundler] ++ defaultBuildInputs ++ extraBuildInputs;
        nativeBuildInputs =
          [ruby]
          ++ (
            if gemset != null && gem_strategy == "bundix"
            then [pkgs.bundler]
            else []
          );
        buildPhase = ''
          export HOME=$TMPDIR
          export GEM_HOME=$TMPDIR/gems
          unset GEM_PATH
          unset $(env | grep ^BUNDLE_ | cut -d= -f1)
          export BUNDLE_HOME=$TMPDIR/.bundle
          export BUNDLE_CONFIG=$TMPDIR/.bundle/config
          export BUNDLE_CACHE=$TMPDIR/.bundle/cache
          export BUNDLE_FROZEN=true
          export PATH=${bundler}/bin:$out/app/vendor/bundle/bin:$PATH
          export BUNDLE_PATH=$out/app/vendor/bundle
          export BUNDLE_GEMFILE=$APP_DIR/Gemfile
          export SECRET_KEY_BASE=dummy_secret_key_for_build
          export RUBYLIB=${ruby}/lib/ruby/${rubyVersion.dotted}
          export RUBYOPT="-r logger"
          mkdir -p $GEM_HOME $out/app/vendor/bundle/bin $TMPDIR/.bundle
          # Copy project .bundle/config if it exists
          if [ -f .bundle/config ]; then
            cp .bundle/config $TMPDIR/.bundle/config
          else
            touch $TMPDIR/.bundle/config
          fi

          echo "Using bundler version:"
          ${bundler}/bin/bundle --version || {
            echo "Failed to run bundle command"
            exit 1
          }
          echo "Checking ${
            if gem_strategy == "vendored"
            then "vendor/cache"
            else "gemset.nix"
          } contents:"
          ${
            if gem_strategy == "vendored"
            then "ls -l vendor/cache"
            else "ls -l gemset.nix || echo 'gemset.nix not found in source'"
          }
          echo "Gemfile.lock contents:"
          cat Gemfile.lock || echo "Gemfile.lock not found, proceeding with installation"
          echo "Gemset status: ${
            if gemset != null
            then "provided"
            else "null"
          }"

          export APP_DIR=$TMPDIR/app
          mkdir -p $APP_DIR
          cp -r . $APP_DIR
          cd $APP_DIR
          ${
            if railsEnv == "production"
            then "export RAILS_SERVE_STATIC_FILES=true"
            else ""
          }
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

          export RAILS_ENV=${railsEnv}
          ${builtins.concatStringsSep "\n" (builtins.attrValues (builtins.mapAttrs (name: value: "export ${name}=${pkgs.lib.escapeShellArg value}") extraEnv))}

          cd $APP_DIR
          ${
            if gem_strategy == "vendored"
            then ''
              ${bundler}/bin/bundle install --local --no-cache --path $out/app/vendor/bundle --binstubs $out/app/vendor/bundle/bin
              echo "Checking $out/app/vendor/bundle contents:"
              find $out/app/vendor/bundle -type f
              echo "Checking for rails executable:"
              find $out/app/vendor/bundle/bin -type f -name rails
              if [ -f "$out/app/vendor/bundle/bin/rails" ]; then
                echo "Rails executable found"
                ${bundler}/bin/bundle exec $out/app/vendor/bundle/bin/rails --version
              else
                echo "Rails executable not found"
                exit 1
              fi
              echo "Testing bundle exec rails:"
              ${bundler}/bin/bundle exec $out/app/vendor/bundle/bin/rails --version
              echo "Testing bundle exec rails assets:precompile:"
              ${bundler}/bin/bundle exec $out/app/vendor/bundle/bin/rails assets:precompile --dry-run
            ''
            else if gem_strategy == "bundix" && gemset != null
            then ''
              ${bundler}/bin/bundle install --local --no-cache --path $out/app/vendor/bundle --binstubs $out/app/vendor/bundle/bin
              echo "Checking $out/app/vendor/bundle contents:"
              find $out/app/vendor/bundle -type f
              echo "Checking for rails executable:"
              find $out/app/vendor/bundle/bin -type f -name rails
              if [ -f "$out/app/vendor/bundle/bin/rails" ]; then
                echo "Rails executable found"
                ${bundler}/bin/bundle exec $out/app/vendor/bundle/bin/rails --version
              else
                echo "Rails executable not found"
                exit 1
              fi
              echo "Testing bundle exec rails:"
              ${bundler}/bin/bundle exec $out/app/vendor/bundle/bin/rails --version
              echo "Testing bundle exec rails assets:precompile:"
              ${bundler}/bin/bundle exec $out/app/vendor/bundle/bin/rails assets:precompile --dry-run
            ''
            else ''
              echo "Error: Invalid gem_strategy '${gem_strategy}' or missing gemset for bundix"
              exit 1
            ''
          }
          ${builtins.concatStringsSep "\n" effectiveBuildCommands}
          pg_ctl -D $PGDATA stop
        '';
        installPhase = ''
          mkdir -p $out/app/bin
          cp -r . $out/app
          cat > $out/app/bin/rails-app <<EOF
          #!${pkgs.runtimeShell}
          export GEM_HOME=\$HOME/.nix-gems
          unset GEM_PATH
          unset \$(env | grep ^BUNDLE_ | cut -d= -f1)
          export BUNDLE_HOME=\$HOME/.bundle
          export BUNDLE_CONFIG=\$HOME/.bundle/config
          export BUNDLE_CACHE=\$HOME/.bundle/cache
          export BUNDLE_PATH=$out/app/vendor/bundle
          export BUNDLE_GEMFILE=/app/Gemfile
          export PATH=${bundler}/bin:\$BUNDLE_PATH/bin:\$PATH
          export RUBYLIB=${ruby}/lib/ruby/${rubyVersion.dotted}
          export RUBYOPT="-r logger"
          mkdir -p \$HOME/.bundle
          cd $out/app
          exec ${bundler}/bin/bundle exec $out/app/vendor/bundle/bin/rails "\$@"
          EOF
          chmod +x $out/app/bin/rails-app
        '';
      };
      bundler = bundler;
    };

    mkAppDevShell = {src}:
      pkgs.mkShell {
        buildInputs = with pkgs; (
          if builtins.pathExists "${src}/vendor/cache"
          then [
            (pkgs."ruby-${(detectRubyVersion {inherit src;}).dotted}")
            (buildRailsApp {inherit src nixpkgsConfig;}).bundler
            (buildRailsApp {inherit src nixpkgsConfig;}).app.buildInputs
          ]
          else [
            (pkgs."ruby-${(detectRubyVersion {inherit src;}).dotted}")
            (buildRailsApp {inherit src nixpkgsConfig;}).bundler
            libyaml
            zlib
            openssl
            libxml2
            libxslt
            nodejs_20
          ]
        );
        shellHook = ''
          unset GEM_HOME GEM_PATH
          unset $(env | grep ^BUNDLE_ | cut -d= -f1)
          export BUNDLE_PATH=$PWD/vendor/bundle
          export BUNDLE_GEMFILE=$PWD/Gemfile
          export BUNDLE_HOME=$HOME/.bundle
          export BUNDLE_CONFIG=$HOME/.bundle/config
          export BUNDLE_CACHE=$HOME/.bundle/cache
          export PATH=$BUNDLE_PATH/bin:${(buildRailsApp {inherit src nixpkgsConfig;}).bundler}/bin:$PATH
          export RUBYLIB=${pkgs."ruby-${(detectRubyVersion {inherit src;}).dotted}"}/lib/ruby/${(detectRubyVersion {inherit src;}).dotted}
          export RUBYOPT="-r logger"
          mkdir -p .nix-gems $BUNDLE_PATH/bin $HOME/.bundle
          ${pkgs.bundler}/bin/bundle config set --local path $BUNDLE_PATH
          ${pkgs.bundler}/bin/bundle config set --local bin $BUNDLE_PATH/bin
          ${pkgs.bundler}/bin/bundle config set --local without development test
          echo "Detected Ruby version: ${(detectRubyVersion {inherit src;}).dotted}"
          echo "Ruby version: ''$(ruby --version)"
          echo "Bundler version: ''$(bundle --version)"
          ${
            if builtins.pathExists "${src}/vendor/cache"
            then ''
              echo "vendor/cache detected. Binstubs are available in vendor/bundle/bin (e.g., vendor/bundle/bin/rails)."
            ''
            else ''
              echo "vendor/cache not found. Run 'bundle install --path vendor/cache' to populate gems."
            ''
          }
          echo "Welcome to the Rails dev shell!"
        '';
      };

    mkBootstrapDevShell = {src}:
      pkgs.mkShell {
        buildInputs = with pkgs; [
          (pkgs."ruby-${(detectRubyVersion {inherit src;}).dotted}")
          (buildRailsApp {
            inherit src nixpkgsConfig;
            defaultBundlerVersion = "2.6.8";
          }).bundler
          libyaml
          zlib
          openssl
          libxml2
          libxslt
          nodejs_20
        ];
        shellHook = ''
          unset GEM_HOME GEM_PATH
          unset $(env | grep ^BUNDLE_ | cut -d= -f1)
          export BUNDLE_PATH=$PWD/vendor/bundle
          export BUNDLE_GEMFILE=$PWD/Gemfile
          export BUNDLE_HOME=$HOME/.bundle
          export BUNDLE_CONFIG=$HOME/.bundle/config
          export BUNDLE_CACHE=$HOME/.bundle/cache
          export PATH=$BUNDLE_PATH/bin:${(buildRailsApp {
            inherit src nixpkgsConfig;
            defaultBundlerVersion = "2.6.8";
          }).bundler}/bin:$PATH
          export RUBYLIB=${pkgs."ruby-${(detectRubyVersion {inherit src;}).dotted}"}/lib/ruby/${(detectRubyVersion {inherit src;}).dotted}
          export RUBYOPT="-r logger"
          mkdir -p .nix-gems $BUNDLE_PATH/bin $HOME/.bundle
          ${pkgs.bundler}/bin/bundle config set --local path $BUNDLE_PATH
          ${pkgs.bundler}/bin/bundle config set --local bin $BUNDLE_PATH/bin
          echo "Detected Ruby version: ${(detectRubyVersion {inherit src;}).dotted}"
          echo "Ruby version: ''$(ruby --version)"
          echo "Bundler version: ''$(bundle --version)"
          echo "Bootstrap shell for new project. Run 'bundle lock' to generate Gemfile.lock, then 'bundle install --path vendor/cache' to populate gems."
          echo "Welcome to the Rails bootstrap shell!"
        '';
      };

    mkRubyShell = {src}:
      pkgs.mkShell {
        buildInputs = with pkgs; [
          (pkgs."ruby-${(detectRubyVersion {inherit src;}).dotted}")
          libyaml
          zlib
          openssl
          libxml2
          libxslt
          imagemagick
          nodejs_20
        ];
        shellHook = ''
          export GEM_HOME=$PWD/.nix-gems
          export PATH=$GEM_HOME/bin:$PATH
          export RUBYLIB=${pkgs."ruby-${(detectRubyVersion {inherit src;}).dotted}"}/lib/ruby/${(detectRubyVersion {inherit src;}).dotted}
          export RUBYOPT="-r logger"
          mkdir -p $GEM_HOME
          echo "Ruby version: ''$(ruby --version)"
          echo "Node.js version: ''$(node --version)"
          echo "Ruby shell with build inputs. Gems are installed in $GEM_HOME."
          echo "Run 'gem install <gem>' to install gems, or use Ruby without Bundler."
        '';
      };

    mkDockerImage = {
      railsApp,
      name,
      debug ? false,
      extraEnv ? [],
    }: let
      startScript = pkgs.writeShellScript "start" ''
        #!/bin/bash
        set -e

        # Check if Procfile exists
        if [ ! -f /app/Procfile ]; then
          echo "Error: /app/Procfile not found. Please provide a Procfile with role commands."
          exit 1
        fi

        # Check if EXECUTION_ROLE is set
        if [ -z "$EXECUTION_ROLE" ]; then
          echo "Error: EXECUTION_ROLE environment variable is not set. Please set it to a valid role (e.g., 'web', 'worker')."
          exit 1
        fi

        # Read Procfile and find the command for EXECUTION_ROLE
        command=$(grep "^$EXECUTION_ROLE:" /app/Procfile | sed "s/^$EXECUTION_ROLE:[[:space:]]*//" | head -n 1)

        # Check if a command was found
        if [ -z "$command" ]; then
          echo "Error: No command found for EXECUTION_ROLE='$EXECUTION_ROLE' in /app/Procfile."
          echo "Available roles:"
          grep "^[a-zA-Z0-9_-]\+:" /app/Procfile | sed 's/^\(.*\):.*/\1/' | sort | uniq
          exit 1
        fi

        # Execute the command
        echo "Starting $EXECUTION_ROLE with command: $command"
        cd /app
        exec $command
      '';
      basePaths = [
        railsApp
        railsApp.buildInputs
        pkgs.bash
      ];
      debugPaths = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.htop
        pkgs.agrep
        pkgs.busybox
        pkgs.less
      ];
    in
      pkgs.dockerTools.buildImage {
        name =
          if debug
          then "${name}-debug"
          else name;
        tag = "latest";
        copyToRoot = pkgs.buildEnv {
          name = "image-root";
          paths =
            basePaths
            ++ (
              if debug
              then debugPaths
              else []
            );
          pathsToLink = ["/app" "/bin"];
        };
        config = {
          Entrypoint = ["/bin/start"];
          WorkingDir = "/app";
          Env =
            [
              "PATH=/app/vendor/bundle/bin:/bin"
              "GEM_HOME=/app/.nix-gems"
              "BUNDLE_PATH=/app/vendor/bundle"
              "BUNDLE_GEMFILE=/app/Gemfile"
              "BUNDLE_HOME=/root/.bundle"
              "BUNDLE_CONFIG=/root/.bundle/config"
              "BUNDLE_CACHE=/root/.bundle/cache"
              "RAILS_ENV=production"
              "RAILS_SERVE_STATIC_FILES=true"
              "DATABASE_URL=postgresql://postgres@localhost/rails_production?host=/var/run/postgresql"
              "RUBYLIB=${railsApp.buildInputs [0]}/lib/ruby/${(detectRubyVersion {src = ./.;}).dotted}"
              "RUBYOPT=-r logger"
            ]
            ++ extraEnv;
          ExposedPorts = {
            "3000/tcp" = {};
          };
        };
      };
  in {
    lib.${system} = {
      inherit detectRubyVersion detectBundlerVersion buildRailsApp nixpkgsConfig mkAppDevShell mkBootstrapDevShell mkRubyShell mkDockerImage;
    };
    packages.${system} = {
      generate-gemset = pkgs.writeShellScriptBin "generate-gemset" ''
        if [ -z "$1" ]; then
          echo "Error: Please provide a source directory path."
          exit 1
        fi
        if [ ! -f "$1/Gemfile.lock" ]; then
          echo "Error: Gemfile.lock is missing in $1."
          exit 1
        fi
        cd "$1"
        ${pkgs.bundix}/bin/bundix
        if [ -f gemset.nix ]; then
          echo "Generated gemset.nix successfully."
        else
          echo "Error: Failed to generate gemset.nix."
          exit 1
        fi
      '';
      debugOpenssl = pkgs.writeShellScriptBin "debug-openssl" ''
        #!${pkgs.runtimeShell}
        echo "OpenSSL versions available:"
        nix eval --raw nixpkgs#openssl.outPath
        nix eval --raw nixpkgs#openssl_1_1.outPath 2>/dev/null || echo "openssl_1_1 not found"
        echo "Permitted insecure packages:"
        echo "${builtins.concatStringsSep ", " nixpkgsConfig.permittedInsecurePackages}"
        echo "Checking if openssl-1.1.1w is allowed:"
        nix eval --raw nixpkgs#openssl_1_1_1w.outPath 2>/dev/null || echo "openssl-1.1.1w is blocked"
      '';
    };
    devShells.${system} = {
      bundix = pkgs.mkShell {
        buildInputs = [pkgs.bundix];
        shellHook = ''
          echo "Run 'bundix' to generate gemset.nix."
        '';
      };
    };
    apps.${system} = {
      flakeVersion = {
        type = "app";
        program = "${pkgs.writeShellScriptBin "flake-version" ''
          #!${pkgs.runtimeShell}
          echo "${flake_version}"
        ''}/bin/flake-version";
      };
    };
    templates = {
      new-app = {
        path = ./templates/new-app;
        description = "A template for initializing a Rails application with Nix flake support";
      };
    };
  };
}
