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
    flake_version = "113";
    bundlerGems = import ./bundler-hashes.nix;

    detectRubyVersion = {
      src,
      rubyVersionSpecified ? null,
    }: let
      version =
        if rubyVersionSpecified != null
        then rubyVersionSpecified
        else if builtins.pathExists "${src}/.ruby-version"
        then let
          rawVersion = builtins.readFile "${src}/.ruby-version";
          cleanedVersion = builtins.replaceStrings ["ruby-" "\n" "\r"] ["" "" ""] rawVersion;
        in
          if cleanedVersion == ""
          then throw "Empty .ruby-version file in ${src}"
          else cleanedVersion
        else throw "Missing .ruby-version file in ${src}";
      underscored = builtins.replaceStrings ["."] ["_"] version;
    in {
      dotted = version;
      underscored = underscored;
    };

    detectBundlerVersion = {
      src,
      defaultVersion ? "2.5.17",
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

    detectRailsVersion = {
      src,
      defaultVersion ? "7.0.0",
    }: let
      lockFile = "${src}/Gemfile.lock";
      fileExists = builtins.pathExists lockFile;
      version =
        if fileExists
        then let
          rawContent = builtins.readFile lockFile;
          allLines = builtins.split "\n" rawContent;
          lines = builtins.filter (line: builtins.typeOf line == "string" && line != "") allLines;
          railsLine = builtins.filter (line: (builtins.match "[[:space:]]*rails \\(([0-9]+\\.[0-9]+\\.[0-9]+(\\.[0-9]+)?)\\)" line) != null) lines;
          versionMatch =
            if railsLine != []
            then builtins.match "[[:space:]]*rails \\(([0-9]+\\.[0-9]+\\.[0-9]+(\\.[0-9]+)?)\\)" (builtins.head railsLine)
            else null;
        in
          if versionMatch != null
          then builtins.head versionMatch
          else defaultVersion
        else defaultVersion;
    in
      version;
    # Start buildRailsApp
    buildRailsApp = {
      system ? "x86_64-linux",
      rubyVersionSpecified ? null,
      gemset ? null,
      src,
      railsEnv ? "production",
      extraEnv ? {},
      extraBuildInputs ? [],
      gem_strategy ? (
        if builtins.pathExists "${src}/gemset.nix"
        then "bundix"
        else "vendored"
      ),
      buildCommands ? null,
      nixpkgsConfig,
      bundlerHashes ? ./bundler-hashes.nix,
      gccVersion ? null,
      packageOverrides ? {},
      historicalNixpkgs ? null,
    }: let
      pkgs = import nixpkgs {
        inherit system;
        config = nixpkgsConfig;
        overlays = [nixpkgs-ruby.overlays.default];
      };
      historicalPkgs =
        if historicalNixpkgs != null
        then import historicalNixpkgs {inherit system;}
        else pkgs;
      effectivePkgs = pkgs // packageOverrides;
      gcc =
        if packageOverrides ? gcc
        then packageOverrides.gcc
        else
          (
            if gccVersion != null
            then historicalPkgs."gcc${gccVersion}"
            else pkgs.gcc
          );
      gemsetExists = builtins.pathExists "${src}/gemset.nix";
      effectiveGemset =
        if gem_strategy == "bundix" && gemset == null && gemsetExists
        then import "${src}/gemset.nix"
        else gemset;
      effectiveGemStrategy = gem_strategy;
      defaultBuildInputs = with effectivePkgs; [
        libyaml
        postgresql
        redis
        zlib
        openssl
        libxml2
        libxslt
        imagemagick
        nodejs_20
        pkg-config
        coreutils
        gcc
        shared-mime-info
        tzdata
        yarn
        icu
        glib
        libxml2
        libxslt
        inetutils
      ];
      rubyVersion = detectRubyVersion {inherit src rubyVersionSpecified;};
      ruby = effectivePkgs."ruby-${rubyVersion.dotted}" or (throw "Ruby version ${rubyVersion.dotted} not found in nixpkgs-ruby");
      bundlerVersion = detectBundlerVersion {inherit src;};
      bundlerGem = bundlerGems."${bundlerVersion}" or (throw "Unsupported bundler version: ${bundlerVersion}. Update bundler-hashes.nix or provide custom bundlerHashes.");
      bundler = effectivePkgs.stdenv.mkDerivation {
        name = "bundler-${bundlerVersion}";
        buildInputs = [ruby effectivePkgs.git];
        src = effectivePkgs.fetchurl {
          url = bundlerGem.url;
          sha256 = bundlerGem.sha256;
        };
        dontUnpack = true;
        installPhase = ''
          echo "******************************************************************"
          echo "Entering install phase"
          echo "******************************************************************"
          export LD_LIBRARY_PATH=${effectivePkgs.postgresql}/lib:${effectivePkgs.libyaml}/lib:$LD_LIBRARY_PATH
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
          if [ -f "$GEM_HOME/gems/bundler-${bundlerVersion}/lib/bundler/templates/Executable.bundler" ]; then
            sed -i 's|#!/usr/bin/env <%= .* %>|#!/usr/bin/env ruby|' "$GEM_HOME/gems/bundler-${bundlerVersion}/lib/bundler/templates/Executable.bundler"
            echo "Patched Executable.bundler template"
          else
            echo "Executable.bundler template not found"
          fi
          if [ -f "$out/bin/bundle" ]; then
            sed -i 's|#!/usr/bin/env ruby|#!${ruby}/bin/ruby|' "$out/bin/bundle"
            echo "Patched shebang in bin/bundle"
          fi
        '';
      };
      bundlerWrapper = pkgs.writeShellScriptBin "bundle" ''
        #!${pkgs.runtimeShell}
        export GEM_HOME=$TMPDIR/gems
        export GEM_PATH=${bundler}/lib/ruby/gems/${rubyVersion.dotted}:$GEM_HOME
        unset RUBYLIB
        exec ${ruby}/bin/ruby ${bundler}/bin/bundle "$@"
      '';
      effectiveBuildCommands =
        if buildCommands == true
        then []
        else if buildCommands == null
        then ["${bundlerWrapper}/bin/bundle exec $out/app/vendor/bundle/bin/rails assets:precompile"]
        else if builtins.isList buildCommands
        then buildCommands
        else [buildCommands];
    in {
      app = effectivePkgs.stdenv.mkDerivation {
        name = "rails-app";
        inherit src extraBuildInputs;
        buildInputs = [ruby bundler] ++ defaultBuildInputs ++ extraBuildInputs;
        nativeBuildInputs = [bundlerWrapper ruby effectivePkgs.git effectivePkgs.coreutils gcc];
        dontPatchShebangs = true;
        buildPhase = ''
                    echo "******************************************************************"
                    echo "Entering build phase for buildRailsApp"
                    echo "******************************************************************"
                    echo "Initial PATH: $PATH"
                    echo "Checking for mkdir:"
                    command -v mkdir || echo "mkdir not found"
                    echo "Checking for coreutils:"
                    ls -l ${effectivePkgs.coreutils}/bin/mkdir || echo "coreutils not found"
                    export PATH=${bundlerWrapper}/bin:${effectivePkgs.coreutils}/bin:${ruby}/bin:$PATH
                    export GEM_HOME=$TMPDIR/gems
                    export GEM_PATH=${bundler}/lib/ruby/gems/${rubyVersion.dotted}:$GEM_HOME
                    unset RUBYLIB

                    export TZDIR=${effectivePkgs.tzdata}/share/zoneinfo
                    export HOME=$TMPDIR
                    unset $(env | grep ^BUNDLE_ | cut -d= -f1)
                    export APP_DIR=$TMPDIR/app
                    mkdir -p $APP_DIR
                    export BUNDLE_USER_CONFIG=$APP_DIR/.bundle/config
                    export BUNDLE_PATH=$APP_DIR/vendor/bundle
                    export BUNDLE_FROZEN=true
                    export BUNDLE_GEMFILE=$APP_DIR/Gemfile
                    export SECRET_KEY_BASE=dummy_secret_key_for_build
                    export RUBYOPT="-r logger"
                    export LD_LIBRARY_PATH=${effectivePkgs.postgresql}/lib:${effectivePkgs.libyaml}/lib:$LD_LIBRARY_PATH
                    export XDG_DATA_DIRS=${effectivePkgs.shared-mime-info}/share:$XDG_DATA_DIRS
                    export FREEDESKTOP_MIME_TYPES_PATH=${effectivePkgs.shared-mime-info}/share/mime/packages/freedesktop.org.xml
                    export TZDIR=${effectivePkgs.tzdata}/share/zoneinfo
                    export REDIS_URL=redis://localhost:6379 #/0 # Default Redis URL for runtime
                    export CC=${gcc}/bin/gcc
                    export CXX=${gcc}/bin/g++
                    echo "Using GCC version: $(${gcc}/bin/gcc --version | head -n 1)"
                    export CFLAGS="-Wno-error=incompatible-pointer-types"

                    echo "\n********************** Environment is set up ********************************************\n"

                    echo "\n********************* Setting up postgres ********************************************\n"

                    echo "Checking for libpq.so:"
                    find ${effectivePkgs.postgresql}/lib -name 'libpq.so*' || echo "libpq.so not found"
                    ${
            if railsEnv == "production"
            then "export RAILS_SERVE_STATIC_FILES=true"
            else ""
          }
                    ## Postgres setup
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

                    echo "\n********************* Setting up redis ********************************************\n"

                    ## Redis setup
                    export REDIS_SOCKET=$TMPDIR/redis.sock
                    export REDIS_PID=$TMPDIR/redis.pid
                    mkdir -p $TMPDIR
                    ${effectivePkgs.redis}/bin/redis-server --unixsocket $REDIS_SOCKET --pidfile $REDIS_PID --daemonize yes --port 6379
                    sleep 2
                    # Verify Redis is running
                    ${effectivePkgs.redis}/bin/redis-cli -s $REDIS_SOCKET ping || { echo "Redis failed to start"; exit 1; }
                    #export REDIS_URL="redis://$REDIS_SOCKET"

                    echo "\n********************* Setting up bundler ********************************************\n"

                    mkdir -p $GEM_HOME $APP_DIR/vendor/bundle/bin $APP_DIR/.bundle
                    echo "Installing bundler ${bundlerVersion} into GEM_HOME..."
                    ${ruby}/bin/gem install --no-document --local ${bundler.src} --install-dir $GEM_HOME --bindir $APP_DIR/vendor/bundle/bin || {
                      echo "Failed to install bundler ${bundlerVersion} into GEM_HOME"
                      exit 1
                    }
                    cat > $APP_DIR/.bundle/config <<EOF
                    ---
                    BUNDLE_PATH: "$APP_DIR/vendor/bundle"
                    BUNDLE_FROZEN: "true"
                    EOF
                    echo "Contents of $APP_DIR/.bundle/config:"
                    cat $APP_DIR/.bundle/config

                    echo "Checking for git availability:"
                    git --version || echo "Git not found"
                    echo "Using bundler version:"
                    ${bundlerWrapper}/bin/bundle --version || {
                      echo "Failed to run bundle command"
                      exit 1
                    }
                    echo "Bundler executable path:"
                    ls -l ${bundlerWrapper}/bin/bundle

                    echo "\n********************** Bundler installed ********************************************\n"
                    echo "\n********************** Deciding bundle strategy ********************************************\n"

                    echo "Detected gem strategy: ${effectiveGemStrategy}"
                    echo "Checking for gemset.nix: ${
            if gemsetExists
            then "found"
            else "not found"
          }"
                    ${
            if effectiveGemStrategy == "bundix"
            then ''
              echo "Checking gemset status: ${
                if effectiveGemset != null && builtins.isAttrs effectiveGemset
                then "provided"
                else "null or invalid"
              }"
              echo "Gemset gem names: ${
                if effectiveGemset != null && builtins.isAttrs effectiveGemset
                then builtins.concatStringsSep ", " (builtins.attrNames effectiveGemset)
                else "none"
              }"
            ''
            else ''
              echo "Vendored strategy: gemset not required"
            ''
          }
                    echo "Checking ${
            if effectiveGemStrategy == "vendored"
            then "vendor/cache"
            else "gemset.nix"
          } contents:"
                    ${
            if effectiveGemStrategy == "vendored"
            then "ls -l vendor/cache || echo 'vendor/cache directory not found'"
            else "ls -l gemset.nix || echo 'gemset.nix not found in source'"
          }
                    #echo "Gemfile.lock contents:"
                    #cat Gemfile.lock || echo "Gemfile.lock not found in source"
                    echo "Activated gems before bundle install:"
                    gem list || echo "Failed to list gems"
                    echo "********** copying to APP_DIR **********"
                    cp -r . $APP_DIR
                    cd $APP_DIR
                    if [ ! -f Gemfile ]; then
                      echo "Gemfile not found in source"
                      exit 1
                    fi
                    if [ ! -f Gemfile.lock ]; then
                      echo "Gemfile.lock not found in source"
                      exit 1
                    fi
                    #echo "Existing files in $out/app/vendor/bundle:"
                    #find $out/app/vendor/bundle -type f 2>/dev/null || echo "No existing files"
                    rm -rf $out/app/vendor/bundle
                    mkdir -p $out/app/vendor/bundle


                    export RAILS_ENV=${railsEnv}
                    ${builtins.concatStringsSep "\n" (builtins.attrValues (builtins.mapAttrs (name: value: "export ${name}=${pkgs.lib.escapeShellArg value}") extraEnv))}
                    echo "\n********************** Bundling... ********************************************\n"

                    cd $APP_DIR
                    ${
            if effectiveGemStrategy == "vendored"
            then ''
              echo "\n********************** using vendored strategy ********************************************\n"
              echo "\n************************** bundler set config  ********************************************\n"
              ${bundlerWrapper}/bin/bundle config set --local path $APP_DIR/vendor/bundle
              ${bundlerWrapper}/bin/bundle config set --local cache_path vendor/cache
              ${bundlerWrapper}/bin/bundle config set --local without development test
              ${bundlerWrapper}/bin/bundle config set --local bin $APP_DIR/vendor/bundle/bin
              echo "Bundler config before install:"
              ${bundlerWrapper}/bin/bundle config
              echo "Listing vendor/cache contents:"
              ls -l vendor/cache || echo "vendor/cache directory not found"
              echo "Listing gem dependencies from Gemfile.lock:"
              ${bundlerWrapper}/bin/bundle list || echo "Failed to list dependencies"
              echo "Bundler environment:"
              env | grep BUNDLE_ || echo "No BUNDLE_ variables set"
              echo "RubyGems environment:"
              gem env
              echo "Attempting bundle install:"
              ${bundlerWrapper}/bin/bundle install --local --no-cache --binstubs $APP_DIR/vendor/bundle/bin --verbose || {
                echo "Bundle install failed, please check vendor/cache and Gemfile.lock for compatibility"
                exit 1
              }
              #echo "Checking $APP_DIR/vendor/bundle contents before copy:"
              #find $APP_DIR/vendor/bundle -type f
              echo "Checking for rails gem in vendor/cache:"
              ls -l vendor/cache | grep rails || echo "Rails gem not found in vendor/cache"
              echo "Checking for pg gem in vendor/cache:"
              ls -l vendor/cache | grep pg || echo "pg gem not found in vendor/cache"
              echo "Copying gems to output path:"
              cp -r $APP_DIR/vendor/bundle/* $out/app/vendor/bundle/
              if [ -d "$out/app/vendor/bundle/bin" ]; then
                for file in $out/app/vendor/bundle/bin/*; do
                  if [ -f "$file" ]; then
                    sed -i 's|#!/usr/bin/env ruby|#!${ruby}/bin/ruby|' "$file"
                  fi
                done
                echo "Manually patched shebangs in $out/app/vendor/bundle/bin"
              fi
              #echo "Checking $out/app/vendor/bundle contents:"
              #find $out/app/vendor/bundle -type f
              echo "Checking for rails executable:"
              if [ -d "$out/app/vendor/bundle/bin" ]; then
                find $out/app/vendor/bundle/bin -type f -name rails
                if [ -f "$out/app/vendor/bundle/bin/rails" ]; then
                  echo "Rails executable found"
                  ${bundlerWrapper}/bin/bundle exec $out/app/vendor/bundle/bin/rails --version
                else
                  echo "Rails executable not found"
                  exit 1
                fi
              else
                echo "Bin directory $out/app/vendor/bundle/bin not found"
                exit 1
              fi
              # Add Rails bin directory to PATH after bundle install, ensuring bundler derivation remains first
              export PATH=${bundlerWrapper}/bin:$APP_DIR/vendor/bundle/bin:${ruby}/bin:$PATH
              echo "\n********************** bundling done ********************************************\n"
            ''
            else if effectiveGemStrategy == "bundix" && effectiveGemset != null && builtins.isAttrs effectiveGemset
            then ''
              echo "\n********************** using bundix strategy ********************************************\n"
              echo "\n************************** bundler set config  ********************************************\n"
              rm -rf $APP_DIR/vendor/bundle/*
              ${bundlerWrapper}/bin/bundle config set --local path $APP_DIR/vendor/bundle
              ${bundlerWrapper}/bin/bundle config set --local without development test
              ${bundlerWrapper}/bin/bundle config set --local bin $APP_DIR/vendor/bundle/bin
              echo "Bundler config before install:"
              ${bundlerWrapper}/bin/bundle config
              echo "Listing gemset.nix:"
              ls -l gemset.nix || echo "gemset.nix not found"
              echo "Listing gem dependencies from Gemfile.lock:"
              ${bundlerWrapper}/bin/bundle list || echo "Failed to list dependencies"
              echo "Bundler environment:"
              env | grep BUNDLE_ || echo "No BUNDLE_ variables set"
              echo "RubyGems environment:"
              gem env
              echo "Activated gems after bundle install:"
              gem list || echo "Failed to list gems"
              echo "Bundler executable path:"
              ls -l ${bundlerWrapper}/bin/bundle
              echo "Attempting bundle install:"
              ${bundlerWrapper}/bin/bundle install --local --no-cache --binstubs $APP_DIR/vendor/bundle/bin --verbose || {
                echo "Bundle install failed, please check gemset.nix for correctness"
                exit 1
              }
              #echo "Checking $APP_DIR/vendor/bundle contents before copy:"
              #find $APP_DIR/vendor/bundle -type f
              echo "Copying gems to output path:"
              cp -r $APP_DIR/vendor/bundle/* $out/app/vendor/bundle/
              if [ -d "$out/app/vendor/bundle/bin" ]; then
                for file in $out/app/vendor/bundle/bin/*; do
                  if [ -f "$file" ]; then
                    sed -i 's|#!/usr/bin/env ruby|#!${ruby}/bin/ruby|' "$file"
                  fi
                done
                echo "Manually patched shebangs in $out/app/vendor/bundle/bin"
              fi
              #echo "Checking $out/app/vendor/bundle contents:"
              #find $out/app/vendor/bundle -type f
              echo "Checking for rails executable:"
              if [ -d "$out/app/vendor/bundle/bin" ]; then
                find $out/app/vendor/bundle/bin -type f -name rails
                if [ -f "$out/app/vendor/bundle/bin/rails" ]; then
                  echo "Rails executable found"
                  ${bundlerWrapper}/bin/bundle exec $out/app/vendor/bundle/bin/rails --version
                else
                  echo "Rails executable not found"
                  exit 1
                fi
              else
                echo "Bin directory $out/app/vendor/bundle/bin not found"
                exit 1
              fi
              # Add Rails bin directory to PATH after bundle install, ensuring bundler derivation remains first
              export PATH=${bundlerWrapper}/bin:$APP_DIR/vendor/bundle/bin:${ruby}/bin:$PATH
              echo "\n********************** bundling done ********************************************\n"
            ''
            else ''
              echo "Error: Invalid gem_strategy '${effectiveGemStrategy}' or missing/invalid gemset for bundix"
              exit 1
            ''
          }
          echo "\r********************** installing javascript dependencies ********************************************\r"

          # JavaScript dependencies
          echo "Checking for JavaScript dependencies..."
          if [ -f "$APP_DIR/yarn.nix" ]; then
            echo "Installing Yarn dependencies..."
            ${effectivePkgs.yarn}/bin/yarn install --offline --frozen-lockfile --modules-folder $APP_DIR/node_modules
          elif [ -f "$APP_DIR/node-packages.nix" ]; then
            echo "Installing npm dependencies..."
            ln -s ${extraBuildInputs.nodeDeps}/lib/node_modules $APP_DIR/node_modules || echo "nodeDeps not provided, skipping npm dependencies"
          elif [ -f "$APP_DIR/config/importmap.rb" ]; then
            echo "Importmaps detected, running importmap install..."
            ${bundlerWrapper}/bin/bundle exec rails importmap:install || echo "Importmap install skipped or not needed"
          else
            echo "No JavaScript dependency files (yarn.nix or node-packages.nix) found, skipping node_modules installation"
          fi
          export NODE_PATH=$APP_DIR/node_modules


          echo "\r********************** executing build commands ********************************************\r"
          ${builtins.concatStringsSep "\n" effectiveBuildCommands}
          # Stop services
          ## Stop Redis
          if [ -f "$REDIS_PID" ]; then
              kill $(cat $REDIS_PID)
              sleep 1
              rm -f $REDIS_PID $REDIS_SOCKET
          fi
          ## Stop postres
          pg_ctl -D $PGDATA stop
        '';
        installPhase = ''
          echo "******************************************************************"
          echo "Entering install phase for buildRailsApp"
          echo "******************************************************************"
          export LD_LIBRARY_PATH=${effectivePkgs.postgresql}/lib:${effectivePkgs.libyaml}/lib:$LD_LIBRARY_PATH
          mkdir -p $out/app/bin $out/app/.bundle
          cp -r . $out/app
          cat > $out/app/bin/rails-app <<EOF
          #!${effectivePkgs.runtimeShell}
          export GEM_HOME=/app/.nix-gems
          export GEM_PATH=${bundler}/lib/ruby/gems/${rubyVersion.dotted}:/app/.nix-gems
          unset RUBYLIB
          unset \$(env | grep ^BUNDLE_ | cut -d= -f1)
          export BUNDLE_USER_CONFIG=/app/.bundle/config
          export BUNDLE_PATH=/app/vendor/bundle
          export BUNDLE_GEMFILE=/app/Gemfile
          export PATH=${bundlerWrapper}/bin:/app/vendor/bundle/bin:\$PATH
          export RUBYOPT="-r logger"
          export XDG_DATA_DIRS=${effectivePkgs.shared-mime-info}/share:\$XDG_DATA_DIRS
          export FREEDESKTOP_MIME_TYPES_PATH=${effectivePkgs.shared-mime-info}/share/mime/packages/freedesktop.org.xml
          export TZDIR=${effectivePkgs.tzdata}/share/zoneinfo
          mkdir -p /app/.bundle
          cd /app
          exec ${bundlerWrapper}/bin/bundle exec /app/vendor/bundle/bin/rails "\$@"
          EOF
          chmod +x $out/app/bin/rails-app
          sed -i 's|#!/usr/bin/env ruby|#!${ruby}/bin/ruby|' "$out/app/bin/rails-app"
        '';
      };
      bundler = bundler;
    }; # End buildRailsApp

    mkAppDevShell = {
      src,
      gccVersion ? null,
      packageOverrides ? {},
      historicalNixpkgs ? null,
    }: let
      effectivePkgs = pkgs // packageOverrides;
      historicalPkgs =
        if historicalNixpkgs != null
        then import historicalNixpkgs {inherit system;}
        else pkgs;
      bundler = (buildRailsApp {inherit src nixpkgsConfig gccVersion packageOverrides historicalNixpkgs;}).bundler;
      ruby = effectivePkgs."ruby-${(detectRubyVersion {inherit src;}).dotted}" or (throw "Ruby version ${(detectRubyVersion {inherit src;}).dotted} not found in nixpkgs-ruby");
      gcc =
        if packageOverrides ? gcc
        then packageOverrides.gcc
        else
          (
            if gccVersion != null
            then historicalPkgs."gcc${gccVersion}"
            else pkgs.gcc
          );
      bundlerVersion = detectBundlerVersion {inherit src;};
    in
      effectivePkgs.mkShell {
        buildInputs = with effectivePkgs; (
          if builtins.pathExists "${src}/vendor/cache"
          then [
            (effectivePkgs."ruby-${(detectRubyVersion {inherit src;}).dotted}" or (throw "Ruby version ${(detectRubyVersion {inherit src;}).dotted} not found"))
            bundler
            (buildRailsApp {inherit src nixpkgsConfig gccVersion packageOverrides historicalNixpkgs;}).app.buildInputs
            git
            gcc
            shared-mime-info
            tzdata
          ]
          else [
            (effectivePkgs."ruby-${(detectRubyVersion {inherit src;}).dotted}" or (throw "Ruby version ${(detectRubyVersion {inherit src;}).dotted} not found"))
            bundler
            git
            libyaml
            postgresql
            zlib
            openssl
            libxml2
            libxslt
            imagemagick
            nodejs_20
            pkg-config
            coreutils
            gcc
            shared-mime-info
            tzdata
          ]
        );
        ## Shell hook for appDevShell
        shellHook = ''
          unset GEM_HOME GEM_PATH
          unset $(env | grep ^BUNDLE_ | cut -d= -f1)
          export HOME=$PWD/.nix-home
          mkdir -p $HOME
          export GEM_HOME=$PWD/.nix-gems
          export GEM_PATH=${bundler}/lib/ruby/gems/${(detectRubyVersion {inherit src;}).dotted}:$GEM_HOME
          unset RUBYLIB
          export BUNDLE_PATH=$PWD/vendor/bundle
          export BUNDLE_GEMFILE=$PWD/Gemfile
          export BUNDLE_USER_CONFIG=$PWD/.bundle/config
          export BUNDLE_IGNORE_CONFIG=1
          export PATH=${bundler}/bin:${ruby}/bin:$PATH
          export RUBYOPT="-r logger"
          export LD_LIBRARY_PATH=${effectivePkgs.postgresql}/lib:${effectivePkgs.libyaml}/lib:$LD_LIBRARY_PATH
          export XDG_DATA_DIRS=${effectivePkgs.shared-mime-info}/share:$XDG_DATA_DIRS
          export FREEDESKTOP_MIME_TYPES_PATH=${effectivePkgs.shared-mime-info}/share/mime/packages/freedesktop.org.xml
          export TZDIR=${effectivePkgs.tzdata}/share/zoneinfo
          export REDIS_URL=redis://localhost:6379/0 # Default Redis URL for runtime
          export CC=${gcc}/bin/gcc
          export CXX=${gcc}/bin/g++
          mkdir -p .nix-gems $BUNDLE_PATH/bin $PWD/.bundle
          echo "Installing bundler ${bundlerVersion} into GEM_HOME..."
          ${ruby}/bin/gem install --no-document --local ${bundler.src} --install-dir $GEM_HOME --bindir $BUNDLE_PATH/bin || {
            echo "Failed to install bundler ${bundlerVersion} into GEM_HOME"
            exit 1
          }
          ${bundler}/bin/bundle config set --local path $BUNDLE_PATH
          ${bundler}/bin/bundle config set --local bin $BUNDLE_PATH/bin
          ${bundler}/bin/bundle config set --local without development test
          # Add Rails bin to PATH after bundle install
          if [ -d "$BUNDLE_PATH/bin" ]; then
            export PATH=$BUNDLE_PATH/bin:$PATH
          fi
          echo "PATH: $PATH"
          echo "GEM_HOME: $GEM_HOME"
          echo "GEM_PATH: $GEM_PATH"
          echo "BUNDLE_PATH: $BUNDLE_PATH"
          echo "BUNDLE_GEMFILE: $BUNDLE_GEMFILE"
          echo "BUNDLE_USER_CONFIG: $BUNDLE_USER_CONFIG"
          echo "BUNDLE_IGNORE_CONFIG: $BUNDLE_IGNORE_CONFIG"
          echo "RUBYOPT: $RUBYOPT"
          echo "TZDIR: $TZDIR"
          echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
          echo "XDG_DATA_DIRS: $XDG_DATA_DIRS"
          echo "FREEDESKTOP_MIME_TYPES_PATH: $FREEDESKTOP_MIME_TYPES_PATH"
          echo "CC: $CC"
          echo "CXX: $CXX"
          echo "Ruby version: ''$(ruby --version)"
          echo "Bundler version: ''$(${bundler}/bin/bundle --version)"
          echo "Welcome to the Rails dev shell!"
        '';
      };

    mkBootstrapDevShell = {
      src,
      gccVersion ? null,
      packageOverrides ? {},
      historicalNixpkgs ? null,
    }: let
      effectivePkgs = pkgs // packageOverrides;
      historicalPkgs =
        if historicalNixpkgs != null
        then import historicalNixpkgs {inherit system;}
        else pkgs;
      bundler = (buildRailsApp {inherit src nixpkgsConfig gccVersion packageOverrides historicalNixpkgs;}).bundler;
      ruby = effectivePkgs."ruby-${(detectRubyVersion {inherit src;}).dotted}" or (throw "Ruby version ${(detectRubyVersion {inherit src;}).dotted} not found in nixpkgs-ruby");
      gcc =
        if packageOverrides ? gcc
        then packageOverrides.gcc
        else
          (
            if gccVersion != null
            then historicalPkgs."gcc${gccVersion}"
            else pkgs.gcc
          );
      bundlerVersion = detectBundlerVersion {inherit src;};
    in
      effectivePkgs.mkShell {
        buildInputs = with effectivePkgs; [
          (effectivePkgs."ruby-${(detectRubyVersion {inherit src;}).dotted}" or (throw "Ruby version ${(detectRubyVersion {inherit src;}).dotted} not found"))
          bundler
          git
          libyaml
          redis
          postgresql
          zlib
          openssl
          libxml2
          libxslt
          nodejs_20
          pkg-config
          coreutils
          gcc
          shared-mime-info
          tzdata
        ];
        # Shellhook for bootStrapDevShell
        shellHook = ''
          unset GEM_HOME GEM_PATH
          unset $(env | grep ^BUNDLE_ | cut -d= -f1)
          export HOME=$PWD/.nix-home
          mkdir -p $HOME
          export GEM_HOME=$PWD/.nix-gems
          export GEM_PATH=${bundler}/lib/ruby/gems/${(detectRubyVersion {inherit src;}).dotted}:$GEM_HOME
          unset RUBYLIB
          export BUNDLE_PATH=$PWD/vendor/bundle
          export BUNDLE_GEMFILE=$PWD/Gemfile
          export BUNDLE_USER_CONFIG=$PWD/.bundle/config
          export BUNDLE_IGNORE_CONFIG=1
          export PATH=${bundler}/bin:${ruby}/bin:$PATH
          export RUBYOPT="-r logger"
          export LD_LIBRARY_PATH=${effectivePkgs.postgresql}/lib:${effectivePkgs.libyaml}/lib:$LD_LIBRARY_PATH
          export XDG_DATA_DIRS=${effectivePkgs.shared-mime-info}/share:$XDG_DATA_DIRS
          export FREEDESKTOP_MIME_TYPES_PATH=${effectivePkgs.shared-mime-info}/share/mime/packages/freedesktop.org.xml
          export TZDIR=${effectivePkgs.tzdata}/share/zoneinfo
          export CC=${gcc}/bin/gcc
          export CXX=${gcc}/bin/g++
          mkdir -p .nix-gems $BUNDLE_PATH/bin $PWD/.bundle
          echo "Installing bundler ${bundlerVersion} into GEM_HOME..."
          ${ruby}/bin/gem install --no-document --local ${bundler.src} --install-dir $GEM_HOME --bindir $BUNDLE_PATH/bin || {
            echo "Failed to install bundler ${bundlerVersion} into GEM_HOME"
            exit 1
          }
          ${bundler}/bin/bundle config set --local path $BUNDLE_PATH
          ${bundler}/bin/bundle config set --local bin $BUNDLE_PATH/bin
          ${bundler}/bin/bundle config set --local without development test
          # Add Rails bin to PATH after bundle install
          if [ -d "$BUNDLE_PATH/bin" ]; then
            export PATH=$BUNDLE_PATH/bin:$PATH
          fi
          echo "PATH: $PATH"
          echo "GEM_HOME: $GEM_HOME"
          echo "GEM_PATH: $GEM_PATH"
          echo "BUNDLE_PATH: $BUNDLE_PATH"
          echo "BUNDLE_GEMFILE: $BUNDLE_GEMFILE"
          echo "BUNDLE_USER_CONFIG: $BUNDLE_USER_CONFIG"
          echo "BUNDLE_IGNORE_CONFIG: $BUNDLE_IGNORE_CONFIG"
          echo "RUBYOPT: $RUBYOPT"
          echo "TZDIR: $TZDIR"
          echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
          echo "XDG_DATA_DIRS: $XDG_DATA_DIRS"
          echo "FREEDESKTOP_MIME_TYPES_PATH: $FREEDESKTOP_MIME_TYPES_PATH"
          export REDIS_URL=redis://localhost:6379 #/0 # Default Redis URL for runtime
          echo "CC: $CC"
          echo "CXX: $CXX"
          echo "Ruby version: ''$(ruby --version)"
          echo "Bundler version: ''$(${bundler}/bin/bundle --version)"
          echo "Welcome to the Rails bootstrap shell!"
        '';
      };

    mkRubyShell = {
      src,
      gccVersion ? null,
      packageOverrides ? {},
      historicalNixpkgs ? null,
    }: let
      effectivePkgs = pkgs // packageOverrides;
      historicalPkgs =
        if historicalNixpkgs != null
        then import historicalNixpkgs {inherit system;}
        else pkgs;
      gcc =
        if packageOverrides ? gcc
        then packageOverrides.gcc
        else
          (
            if gccVersion != null
            then historicalPkgs."gcc${gccVersion}"
            else pkgs.gcc
          );
      ruby = effectivePkgs."ruby-${(detectRubyVersion {inherit src;}).dotted}" or (throw "Ruby version ${(detectRubyVersion {inherit src;}).dotted} not found in nixpkgs-ruby");
    in
      effectivePkgs.mkShell {
        buildInputs = with effectivePkgs; [
          (effectivePkgs."ruby-${(detectRubyVersion {inherit src;}).dotted}" or (throw "Ruby version ${(detectRubyVersion {inherit src;}).dotted} not found"))
          git
          libyaml
          postgresql
          redis
          zlib
          openssl
          libxml2
          libxslt
          imagemagick
          nodejs_20
          pkg-config
          coreutils
          gcc
          shared-mime-info
          tzdata
        ];
        # Shell shook for mkRubyShell
        shellHook = ''
          unset GEM_HOME GEM_PATH
          unset $(env | grep ^BUNDLE_ | cut -d= -f1)
          export HOME=$PWD/.nix-home
          mkdir -p $HOME
          export GEM_HOME=$PWD/.nix-gems
          export PATH=$GEM_HOME/bin:${ruby}/bin:$PATH
          unset RUBYLIB
          export RUBYOPT="-r logger"
          export LD_LIBRARY_PATH=${effectivePkgs.postgresql}/lib:$LD_LIBRARY_PATH
          export LD_LIBRARY_PATH=${effectivePkgs.postgresql}/lib:${effectivePkgs.libyaml}/lib:$LD_LIBRARY_PATH
          export XDG_DATA_DIRS=${effectivePkgs.shared-mime-info}/share:$XDG_DATA_DIRS
          export FREEDESKTOP_MIME_TYPES_PATH=${effectivePkgs.shared-mime-info}/share/mime/packages/freedesktop.org.xml
          export TZDIR=${effectivePkgs.tzdata}/share/zoneinfo
          export CC=${gcc}/bin/gcc
          export CXX=${gcc}/bin/g++
          echo "PATH: $PATH"
          echo "GEM_HOME: $GEM_HOME"
          echo "RUBYOPT: $RUBYOPT"
          echo "TZDIR: $TZDIR"
          echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
          echo "XDG_DATA_DIRS: $XDG_DATA_DIRS"
          echo "FREEDESKTOP_MIME_TYPES_PATH: $FREEDESKTOP_MIME_TYPES_PATH"
          echo "CC: $CC"
          echo "CXX: $CXX"
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
      ruby,
      bundler,
    }: let
      startScript = pkgs.writeShellScript "start" ''
        #!/bin/bash
        set -e
        if [ ! -f /app/Procfile ]; then
          echo "Error: /app/Procfile not found. Please provide a Procfile with role commands."
          exit 1
        fi
        if [ -z "$EXECUTION_ROLE" ]; then
          echo "Error: EXECUTION_ROLE environment variable is not set. Please set it to a valid role (e.g., 'web', 'worker')."
          exit 1
        fi
        command=$(grep "^$EXECUTION_ROLE:" /app/Procfile | sed "s/^$EXECUTION_ROLE:[[:space:]]*//" | head -n 1)
        if [ -z "$command" ]; then
          echo "Error: No command found for EXECUTION_ROLE='$EXECUTION_ROLE' in /app/Procfile."
          echo "Available roles:"
          grep "^[a-zA-Z0-9_-]\+:" /app/Procfile | sed 's/^\(.*\):.*/\1/' | sort | uniq
          exit 1
        fi
        echo "Starting $EXECUTION_ROLE with command: $command"
        cd /app
        exec $command
      '';
      basePaths = [
        railsApp
        railsApp.buildInputs
        pkgs.bash
        pkgs.postgresql
        pkgs.redis
        pkgs.shared-mime-info
        pkgs.tzdata
      ];
      debugPaths = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.htop
        pkgs.agrep
        pkgs.busybox
        pkgs.less
      ];
      rubyVersion = let
        match = builtins.match "ruby-([0-9.]+)" ruby.name;
      in {
        dotted =
          if match != null
          then builtins.head match
          else throw "Cannot derive Ruby version from ${ruby.name}";
        underscored = builtins.replaceStrings ["."] ["_"] (
          if match != null
          then builtins.head match
          else throw "Cannot derive Ruby version from ${ruby.name}"
        );
      };
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
          pathsToLink = ["/app" "/bin" "/lib" "/share"];
        };
        config = {
          Entrypoint = ["/bin/start"];
          WorkingDir = "/app";
          Env =
            [
              "PATH=${bundler}/bin:/app/vendor/bundle/bin:/bin"
              "GEM_HOME=/app/.nix-gems"
              "GEM_PATH=${bundler}/lib/ruby/gems/${rubyVersion.dotted}:/app/.nix-gems"
              "BUNDLE_PATH=/app/vendor/bundle"
              "BUNDLE_GEMFILE=/app/Gemfile"
              "BUNDLE_USER_CONFIG=/app/.bundle/config"
              "RAILS_ENV=production"
              "RAILS_SERVE_STATIC_FILES=true"
              "DATABASE_URL=postgresql://postgres@localhost/rails_production?host=/var/run/postgresql"
              "RUBYOPT=-r logger"
              "LD_LIBRARY_PATH=/lib:$LD_LIBRARY_PATH"
              "XDG_DATA_DIRS=/share:$XDG_DATA_DIRS"
              "FREEDESKTOP_MIME_TYPES_PATH=/share/mime/packages/freedesktop.org.xml"
              "TZDIR=${pkgs.tzdata}/share/zoneinfo"
            ]
            ++ extraEnv;
          ExposedPorts = {
            "3000/tcp" = {};
          };
        };
      };
  in {
    lib.${system} = {
      inherit detectRubyVersion detectBundlerVersion buildRailsApp nixpkgsConfig mkAppDevShell mkBootstrapDevShell mkRubyShell mkDockerImage detectRailsVersion;
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
        nix eval --raw nixpkgs#openssl_1_1_1w.outPath 2>/dev/null || echo "openssl_1.1.1w is blocked"
      '';
    };
    devShells.${system} = {
      bundix = pkgs.mkShell {
        buildInputs = with pkgs; [
          bundix
          git
          (pkgs."ruby-${(detectRubyVersion {src = ./.;}).dotted}" or (throw "Ruby version ${(detectRubyVersion {src = ./.;}).dotted} not found"))
          (buildRailsApp {
            src = ./.;
            inherit nixpkgsConfig;
            gccVersion = null;
            packageOverrides = {};
            historicalNixpkgs = null;
          }).bundler
        ];

        shellHook = ''
          unset GEM_HOME GEM_PATH
          unset $(env | grep ^BUNDLE_ | cut -d= -f1)
          export HOME=$PWD/.nix-home
          mkdir -p $HOME
          export PATH=${(buildRailsApp {
            src = ./.;
            inherit nixpkgsConfig;
            gccVersion = null;
            packageOverrides = {};
            historicalNixpkgs = null;
          }).bundler}/bin:$PATH
          export XDG_DATA_DIRS=${pkgs.shared-mime-info}/share:$XDG_DATA_DIRS
          export FREEDESKTOP_MIME_TYPES_PATH=${pkgs.shared-mime-info}/share/mime/packages/freedesktop.org.xml
          export TZDIR=${pkgs.tzdata}/share/zoneinfo
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
      detectBundlerVersion = {
        type = "app";
        program = "${pkgs.writeShellScriptBin "detect-bundler-version" ''
          #!${pkgs.runtimeShell}
          echo "${detectBundlerVersion {src = ./.;}}"
        ''}/bin/detect-bundler-version";
      };
      detectRailsVersion = {
        type = "app";
        program = "${pkgs.writeShellScriptBin "detect-rails-version" ''
          #!${pkgs.runtimeShell}
          echo "${detectRailsVersion {src = ./.;}}"
        ''}/bin/detect-rails-version";
      };
      detectRubyVersion = {
        type = "app";
        program = "${pkgs.writeShellScriptBin "detect-ruby-version" ''
          #!${pkgs.runtimeShell}
          echo "${detectRubyVersion {src = ./.;}.dotted}"
        ''}/bin/detect-ruby-version";
      };
    };
    flake_version = flake_version;
    templates = {
      new-app = {
        path = ./templates/new-app;
        description = "A template for initializing a Rails application with Nix flake support";
      };
    };
  };
}
