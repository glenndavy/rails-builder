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
    flake_version = "112.84"; # Incremented for package.json patch and shell fixes
    bundlerGems = import ./bundler-hashes.nix;

    # Define ruby and bundler at top level
    ruby = pkgs."ruby-3.3.5" or (throw "Ruby version 3.3.5 not found in nixpkgs-ruby");
    bundlerVersion = "2.5.16";
    bundlerGem = bundlerGems."${bundlerVersion}" or (throw "Unsupported bundler version: ${bundlerVersion}. Update bundler-hashes.nix.");
    bundler = pkgs.stdenv.mkDerivation {
      name = "bundler-${bundlerVersion}";
      buildInputs = [ruby pkgs.git];
      src = pkgs.fetchurl {
        url = bundlerGem.url;
        sha256 = bundlerGem.sha256;
      };
      dontUnpack = true;
      installPhase = ''
        export LD_LIBRARY_PATH=${pkgs.postgresql}/lib:${pkgs.libyaml}/lib:$LD_LIBRARY_PATH
        export HOME=$TMPDIR
        export GEM_HOME=$out/lib/ruby/gems/3.3.0
        export GEM_PATH=$GEM_HOME
        export PATH=$out/bin:$PATH
        mkdir -p $GEM_HOME $out/bin
        gem install --no-document --local $src --install-dir $GEM_HOME --bindir $out/bin
        if [ -f "$out/bin/bundle" ]; then
          sed -i 's|#!/usr/bin/env ruby|#!${ruby}/bin/ruby|' "$out/bin/bundle"
        fi
      '';
    };
    bundlerWrapper = pkgs.writeShellScriptBin "bundle" ''
      #!${pkgs.runtimeShell}
      export GEM_HOME=$TMPDIR/gems
      export GEM_PATH=${bundler}/lib/ruby/gems/3.3.0:$GEM_HOME:$TMPDIR/vendor/bundle/ruby/3.3.0
      export BUNDLE_PATH=$TMPDIR/vendor/bundle
      export BUNDLE_GEMFILE=$PWD/Gemfile
      unset RUBYLIB
      exec ${ruby}/bin/ruby ${bundler}/bin/bundle "$@"
    '';

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

    detectBundlerVersion = {src}: let
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
        else throw "Gemfile.lock is missing in ${src}. Please provide a valid Gemfile.lock.";
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
      nixpkgsConfig,
      bundlerHashes ? ./bundler-hashes.nix,
      gccVersion ? null,
      packageOverrides ? {},
      historicalNixpkgs ? null,
      buildCommands ? null,
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
      rubyVersion = detectRubyVersion {inherit src rubyVersionSpecified;};
      appRuby = effectivePkgs."ruby-${rubyVersion.dotted}" or (throw "Ruby version ${rubyVersion.dotted} not found in nixpkgs-ruby");
      appBundlerVersion = detectBundlerVersion {inherit src;};
      appBundlerGem = bundlerGems."${appBundlerVersion}" or (throw "Unsupported bundler version: ${appBundlerVersion}. Update bundler-hashes.nix or provide custom bundlerHashes.");
      appBundler = effectivePkgs.stdenv.mkDerivation {
        name = "bundler-${appBundlerVersion}";
        buildInputs = [appRuby effectivePkgs.git];
        src = effectivePkgs.fetchurl {
          url = appBundlerGem.url;
          sha256 = appBundlerGem.sha256;
        };
        dontUnpack = true;
        installPhase = ''
          export LD_LIBRARY_PATH=${effectivePkgs.postgresql}/lib:${effectivePkgs.libyaml}/lib:$LD_LIBRARY_PATH
          export HOME=$TMPDIR
          export GEM_HOME=$out/lib/ruby/gems/${rubyVersion.dotted}
          export GEM_PATH=$GEM_HOME
          export PATH=$out/bin:$PATH
          mkdir -p $GEM_HOME $out/bin
          gem install --no-document --local $src --install-dir $GEM_HOME --bindir $out/bin
          if [ -f "$out/bin/bundle" ]; then
            sed -i 's|#!/usr/bin/env ruby|#!${appRuby}/bin/ruby|' "$out/bin/bundle"
          fi
        '';
      };
      appBundlerWrapper = pkgs.writeShellScriptBin "bundle" ''
        #!${pkgs.runtimeShell}
        export GEM_HOME=$TMPDIR/gems
        export GEM_PATH=${appBundler}/lib/ruby/gems/${rubyVersion.dotted}:$GEM_HOME:$TMPDIR/vendor/bundle/ruby/3.3.0
        export BUNDLE_PATH=$TMPDIR/vendor/bundle
        export BUNDLE_GEMFILE=$PWD/Gemfile
        unset RUBYLIB
        exec ${ruby}/bin/ruby ${appBundler}/bin/bundle "$@"
      '';
      webpackScript = pkgs.writeTextFile {
        name = "webpack";
        text = ''
          #!${pkgs.runtimeShell}
          export NODE_PATH=$TMPDIR/node_modules:${effectivePkgs.nodejs_20}/lib/node_modules:$NODE_PATH
          echo "DEBUG: Executing webpack from: $(pwd)"
          echo "DEBUG: NODE_PATH: $NODE_PATH"
          echo "DEBUG: Webpack path: $TMPDIR/node_modules/.bin/webpack"
          if [ -f "$TMPDIR/node_modules/.bin/webpack" ]; then
            ${effectivePkgs.nodejs_20}/bin/node $TMPDIR/node_modules/.bin/webpack --version || {
              echo "ERROR: Failed to run webpack directly"
              exit 1
            }
          else
            echo "ERROR: Webpack executable not found at $TMPDIR/node_modules/.bin/webpack"
            exit 1
          fi
        '';
        executable = true;
      };
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
        dart-sass
        nodePackages.webpack-cli
      ];
      defaultBuildCommands = ["${appRuby}/bin/ruby $TMPDIR/vendor/bundle/bin/rails assets:precompile"];
      effectiveBuildCommands =
        if buildCommands == true
        then []
        else if buildCommands == null
        then defaultBuildCommands
        else if builtins.isList buildCommands
        then buildCommands
        else [buildCommands];
    in {
      app = effectivePkgs.stdenv.mkDerivation {
        name = "rails-app-${flake_version}";
        inherit src extraBuildInputs;
        buildInputs = [appRuby appBundler] ++ defaultBuildInputs ++ extraBuildInputs;
        nativeBuildInputs = [appBundlerWrapper appRuby effectivePkgs.git effectivePkgs.coreutils gcc];
        dontPatchShebangs = true;
        buildPhase = ''
                    echo "******************************************************************"
                    echo "Entering build phase for buildRailsApp (version ${flake_version})"
                    echo "******************************************************************"
                    export PATH=${appBundlerWrapper}/bin:${effectivePkgs.coreutils}/bin:${appRuby}/bin:${effectivePkgs.yarn}/bin:${effectivePkgs.dart-sass}/bin:${effectivePkgs.nodejs_20}/bin:${effectivePkgs.nodePackages.webpack-cli}/bin:$TMPDIR/vendor/bundle/bin:$PATH
                    export GEM_HOME=$TMPDIR/gems
                    export GEM_PATH=${appBundler}/lib/ruby/gems/${rubyVersion.dotted}:$GEM_HOME:$TMPDIR/vendor/bundle/ruby/3.3.0
                    export NODE_PATH=$TMPDIR/node_modules:${effectivePkgs.nodejs_20}/lib/node_modules:$NODE_PATH
                    export HOME=$TMPDIR
                    unset $(env | grep ^BUNDLE_ | cut -d= -f1)
                    export BUNDLE_PATH=$TMPDIR/vendor/bundle
                    export BUNDLE_FROZEN=true
                    export BUNDLE_GEMFILE=$PWD/Gemfile
                    export SECRET_KEY_BASE=dummy_secret_key_for_build
                    export RUBYOPT="-r logger"
                    export LD_LIBRARY_PATH=${effectivePkgs.postgresql}/lib:${effectivePkgs.libyaml}/lib:${appRuby}/lib:$LD_LIBRARY_PATH
                    export XDG_DATA_DIRS=${effectivePkgs.shared-mime-info}/share:$XDG_DATA_DIRS
                    export FREEDESKTOP_MIME_TYPES_PATH=${effectivePkgs.shared-mime-info}/share/mime/packages/freedesktop.org.xml
                    export TZDIR=${effectivePkgs.tzdata}/share/zoneinfo
                    export REDIS_URL=redis://localhost:6379
                    export CC=${gcc}/bin/gcc
                    export CXX=${gcc}/bin/g++
                    export CFLAGS="-Wno-error=incompatible-pointer-types"

                    echo "\n********************** Environment is set up ********************************************\n"
                    echo "NODE_PATH: $NODE_PATH"
                    echo "PATH: $PATH"
                    echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"

                    echo "\n********************* Setting up postgres ********************************************\n"
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
                    export REDIS_SOCKET=$TMPDIR/redis.sock
                    export REDIS_PID=$TMPDIR/redis.pid
                    mkdir -p $TMPDIR
                    ${effectivePkgs.redis}/bin/redis-server --unixsocket $REDIS_SOCKET --pidfile $REDIS_PID --daemonize yes --port 6379
                    sleep 2
                    ${effectivePkgs.redis}/bin/redis-cli -s $REDIS_SOCKET ping || { echo "Redis failed to start"; exit 1; }

                    echo "\n********************* Setting up bundler ********************************************\n"
                    mkdir -p $GEM_HOME $TMPDIR/vendor/bundle/bin $TMPDIR/.bundle
                    echo "Installing bundler ${appBundlerVersion} into GEM_HOME..."
                    ${appRuby}/bin/gem install --no-document --local ${appBundler.src} --install-dir $GEM_HOME --bindir $TMPDIR/vendor/bundle/bin || {
                      echo "Failed to install bundler ${appBundlerVersion} into GEM_HOME"
                      exit 1
                    }
                    cat > $TMPDIR/.bundle/config <<'EOF'
          ---
          BUNDLE_PATH: "$TMPDIR/vendor/bundle"
          BUNDLE_FROZEN: "true"
          BUNDLE_GEMFILE: "$PWD/Gemfile"
          EOF
                    sync
                    echo "Contents of $TMPDIR/.bundle/config:"
                    cat $TMPDIR/.bundle/config || { echo "Failed to read .bundle/config"; exit 1; }

                    echo "Checking for git availability:"
                    git --version || echo "Git not found"
                    echo "Using bundler version:"
                    ${appBundlerWrapper}/bin/bundle --version || {
                      echo "Failed to run bundle command"
                      exit 1
                    }

                    echo "\n********************** Bundler installed ********************************************\n"
                    echo "\n********************** Deciding bundle strategy ********************************************\n"
                    echo "Detected gem strategy: ${effectiveGemStrategy}"
                    if [ "${effectiveGemStrategy}" = "vendored" ]; then
                      echo "\n********************** using vendored strategy ********************************************\n"
                      ${appBundlerWrapper}/bin/bundle config set --local path $TMPDIR/vendor/bundle
                      ${appBundlerWrapper}/bin/bundle config set --local cache_path vendor/cache
                      ${appBundlerWrapper}/bin/bundle config set --local without development test
                      ${appBundlerWrapper}/bin/bundle config set --local bin $TMPDIR/vendor/bundle/bin
                      echo "Bundler config before install:"
                      ${appBundlerWrapper}/bin/bundle config
                      echo "Listing vendor/cache contents:"
                      ls -l vendor/cache || echo "vendor/cache directory not found"
                      echo "Attempting bundle install:"
                      ${appBundlerWrapper}/bin/bundle install --local --no-cache --binstubs $TMPDIR/vendor/bundle/bin --verbose || {
                        echo "Bundle install failed, please check vendor/cache and Gemfile.lock for compatibility"
                        exit 1
                      }
                      mkdir -p $out/app/vendor/bundle
                      cp -r $TMPDIR/vendor/bundle/* $out/app/vendor/bundle/
                      if [ -d "$out/app/vendor/bundle/bin" ]; then
                        for file in $out/app/vendor/bundle/bin/*; do
                          if [ -f "$file" ]; then
                            sed -i 's|#!/usr/bin/env ruby|#!${appRuby}/bin/ruby|' "$file"
                          fi
                        done
                        echo "Manually patched shebangs in $out/app/vendor/bundle/bin"
                      fi
                      echo "Checking for rails executable:"
                      if [ -f "$out/app/vendor/bundle/bin/rails" ]; then
                        echo "Rails executable found"
                        ${appBundlerWrapper}/bin/bundle exec $out/app/vendor/bundle/bin/rails --version
                      else
                        echo "ERROR: Rails executable not found in $out/app/vendor/bundle/bin"
                        exit 1
                      fi
                      export PATH=${appBundlerWrapper}/bin:${effectivePkgs.yarn}/bin:${effectivePkgs.dart-sass}/bin:${effectivePkgs.nodePackages.webpack-cli}/bin:$TMPDIR/vendor/bundle/bin:${appRuby}/bin:${effectivePkgs.nodejs_20}/bin:$TMPDIR/node_modules/.bin:$PATH
                      echo "\n********************** bundling done ********************************************\n"
                    else
                      echo "Error: Only vendored gem strategy is supported in this version"
                      exit 1
                    fi

                    echo "\n********************** installing javascript dependencies ********************************************\n"
                    echo "DEBUG: Starting JavaScript dependency installation..."
                    mkdir -p $TMPDIR/node_modules $TMPDIR/yarn-cache
                    if [ -d "${src}/tmp/yarn-cache" ]; then
                      echo "DEBUG: Found tmp/yarn-cache, copying to $TMPDIR/yarn-cache"
                      cp -r ${src}/tmp/yarn-cache/. $TMPDIR/yarn-cache/ || {
                        echo "ERROR: Failed to copy tmp/yarn-cache"
                        exit 1
                      }
                      echo "DEBUG: Copied tmp/yarn-cache to $TMPDIR/yarn-cache"
                      echo "DEBUG: Setting permissions for yarn-cache"
                      chmod -R u+w $TMPDIR/yarn-cache || {
                        echo "ERROR: Failed to set write permissions on $TMPDIR/yarn-cache"
                        exit 1
                      }
                      echo "DEBUG: Listing yarn cache contents:"
                      ls -R $TMPDIR/yarn-cache || echo "No files in yarn cache"
                      echo "DEBUG: Checking for graphql-tag in cache:"
                      find $TMPDIR/yarn-cache -name "graphql-tag*"
                      echo "DEBUG: Checking for hoist-non-react-statics in cache:"
                      find $TMPDIR/yarn-cache -name "hoist-non-react-statics*"
                    else
                      echo "ERROR: No tmp/yarn-cache found in app source"
                      exit 1
                    fi
                    if [ -d "${src}/tmp/node_modules" ]; then
                      cp -r ${src}/tmp/node_modules/. $TMPDIR/node_modules/ || {
                        echo "ERROR: Failed to copy tmp/node_modules"
                        exit 1
                      }
                      echo "DEBUG: Copied tmp/node_modules to $TMPDIR/node_modules"
                      echo "DEBUG: Checking for ag-grid-community in node_modules:"
                      ls -l $TMPDIR/node_modules/ag-grid-community || echo "ag-grid-community not found in node_modules"
                      if [ -f "$TMPDIR/node_modules/.bin/webpack" ]; then
                        chmod +x $TMPDIR/node_modules/.bin/webpack
                        ${effectivePkgs.nodejs_20}/bin/node $TMPDIR/node_modules/.bin/webpack --version || {
                          echo "ERROR: Failed to run webpack directly"
                          exit 1
                        }
                      else
                        echo "ERROR: webpack executable not found in $TMPDIR/node_modules/.bin"
                        exit 1
                      fi
                    fi
                    if [ -f yarn.lock ]; then
                      echo "DEBUG: Found yarn.lock, contents:"
                      cat yarn.lock
                      echo "DEBUG: Checking yarn.lock for graphql-tag:"
                      grep "graphql-tag" yarn.lock || echo "No graphql-tag found in yarn.lock"
                      echo "DEBUG: Checking yarn.lock for hoist-non-react-statics:"
                      grep "hoist-non-react-statics" yarn.lock || echo "No hoist-non-react-statics found in yarn.lock"
                      echo "DEBUG: Checking yarn.lock for ag-grid-community:"
                      grep "ag-grid-community" yarn.lock || echo "No ag-grid-community found in yarn.lock"
                      echo "DEBUG: Running yarn install --offline --frozen-lockfile"
                      ${effectivePkgs.yarn}/bin/yarn install --offline --frozen-lockfile --cache-folder $TMPDIR/yarn-cache --modules-folder $TMPDIR/node_modules --verbose || {
                        echo "ERROR: yarn install --offline failed"
                        exit 1
                      }
                      echo "DEBUG: Yarn install completed successfully"
                    fi
                    if [ -f package.json ]; then
                      echo "DEBUG: Patching package.json to skip yarn install for css:install"
                      sed -i '/"install":/d' package.json || echo "No install script found in package.json"
                      echo "DEBUG: package.json contents after patching:"
                      cat package.json
                      echo "DEBUG: Updating package.json build:css script to use dart-sass with node_modules path"
                      sed -i 's|"build:css":.*sass |"build:css": "${effectivePkgs.dart-sass}/bin/sass --load-path=$TMPDIR/node_modules app/assets/stylesheets/application.sass.scss:app/assets/builds/application.css |' package.json
                      echo "DEBUG: package.json contents after build:css patching:"
                      cat package.json
                    fi
                    if [ -f bin/webpack ]; then
                      echo "DEBUG: Copying webpack script to bin/webpack"
                      cp ${webpackScript} bin/webpack
                      chmod +x bin/webpack
                      echo "DEBUG: Running bin/webpack --version"
                      ./bin/webpack --version || {
                        echo "ERROR: Failed to execute bin/webpack"
                        exit 1
                      }
                    fi
                    echo "DEBUG: Checking Webpacker entry points:"
                    if [ -f app/javascript/packs/application.js ]; then
                      echo "DEBUG: Found Webpacker entry point: app/javascript/packs/application.js"
                    else
                      echo "ERROR: No Webpacker entry point found"
                      exit 1
                    fi
                    echo "DEBUG: Checking for src directory:"
                    if [ -d app/javascript/src ]; then
                      echo "DEBUG: Found app/javascript/src directory"
                      ls -R app/javascript/src
                    fi
                    if [ -f config/webpacker.yml ]; then
                      echo "DEBUG: Found config/webpacker.yml:"
                      cat config/webpacker.yml
                      grep -q "source_path:.*src" config/webpacker.yml && {
                        sed -i 's/source_path:.*src/source_path: app\/javascript/' config/webpacker.yml
                        echo "DEBUG: Updated config/webpacker.yml:"
                        cat config/webpacker.yml
                      }
                    else
                      echo "DEBUG: Creating default config/webpacker.yml"
                      cat > config/webpacker.yml <<'EOF'
          default:
            source_path: app/javascript
            source_entry_path: packs
            public_output_path: packs
            cache_path: tmp/cache/webpacker
            cache: true
            webpack_compile_output: true
          production:
            <<: *default
            cache: false
          EOF
                    fi
                    if [ -d config/webpack ]; then
                      if [ -f config/webpack/environment.js ]; then
                        echo "const { environment } = require('@rails/webpacker')\nenvironment.config.merge({ entry: './app/javascript/packs/application.js', resolve: { modules: ['node_modules', './app/javascript'] } })\nmodule.exports = environment" > config/webpack/environment.js
                      else
                        echo "DEBUG: Patching config/webpack/environment.js"
                        echo "const { environment } = require('@rails/webpacker')\nconst customConfig = require('./custom')\nenvironment.config.merge({ entry: './app/javascript/packs/application.js', resolve: { modules: ['node_modules', './app/javascript'], alias: customConfig.resolve ? customConfig.resolve.alias : {} } })\nmodule.exports = environment" > config/webpack/environment.js
                      fi
                      if [ -f config/webpack/custom.js ]; then
                        echo "DEBUG: Patching config/webpack/custom.js"
                        echo "const originalConfig = require('./custom')\nmodule.exports = { ...originalConfig, entry: './app/javascript/packs/application.js' }" > config/webpack/custom.js
                      fi
                      if [ -f config/webpack/production.js ]; then
                        sed -i '/entry:.*src/d' config/webpack/production.js
                      fi
                      if [ -f config/webpack/split_chunks.js ]; then
                        sed -i '/entry:.*src/d' config/webpack/split_chunks.js
                      fi
                    fi
                    if grep -q "./src" app/javascript/packs/application.js; then
                      echo "DEBUG: Patching app/javascript/packs/application.js"
                      sed -i 's|\./src|./app/javascript/src|g' app/javascript/packs/application.js
                    fi
                    if [ -f app/assets/stylesheets/application.sass.scss ]; then
                      echo "DEBUG: Contents of application.sass.scss:"
                      cat app/assets/stylesheets/application.sass.scss
                    fi
                    echo "DEBUG: Running yarn build:css:"
                    ${effectivePkgs.yarn}/bin/yarn build:css || {
                      echo "ERROR: yarn build:css failed"
                      exit 1
                    }

                    echo "\n********************** ensuring yarn dependencies for cssbundling-rails ********************************************\n"
                    echo "DEBUG: Verifying yarn dependencies before assets:precompile"
                    if [ -f yarn.lock ]; then
                      echo "DEBUG: Running yarn install --offline --frozen-lockfile to ensure dependencies"
                      ${effectivePkgs.yarn}/bin/yarn install --offline --frozen-lockfile --cache-folder $TMPDIR/yarn-cache --modules-folder $TMPDIR/node_modules --verbose || {
                        echo "ERROR: yarn install --offline for cssbundling-rails failed"
                        exit 1
                      }
                      echo "DEBUG: Listing node_modules after yarn install:"
                      ls -l $TMPDIR/node_modules | grep -E "sass|postcss" || echo "No sass or postcss found in node_modules"
                    else
                      echo "ERROR: yarn.lock not found"
                      exit 1
                    fi

                    echo "\n********************** executing build commands ********************************************\n"
                    echo "DEBUG: Bundler environment before rails assets:precompile:"
                    echo "PATH: $PATH"
                    echo "BUNDLE_PATH: $BUNDLE_PATH"
                    echo "BUNDLE_GEMFILE: $BUNDLE_GEMFILE"
                    echo "GEM_PATH: $GEM_PATH"
                    echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
                    ${appBundlerWrapper}/bin/bundle config
                    ${appBundlerWrapper}/bin/bundle list | grep rails || echo "Rails gem not found in bundle list"
                    echo "Checking ruby executable:"
                    if [ -f "${appRuby}/bin/ruby" ]; then
                      echo "Ruby executable found at ${appRuby}/bin/ruby"
                      ls -l ${appRuby}/bin/ruby
                      ${appRuby}/bin/ruby --version
                    else
                      echo "ERROR: Ruby executable not found at ${appRuby}/bin/ruby"
                      exit 1
                    fi
                    echo "Checking rails executable:"
                    if [ -f "$TMPDIR/vendor/bundle/bin/rails" ]; then
                      echo "Rails executable found at $TMPDIR/vendor/bundle/bin/rails"
                      ls -l $TMPDIR/vendor/bundle/bin/rails
                      sed -i 's|#!/usr/bin/env ruby|#!${appRuby}/bin/ruby|' "$TMPDIR/vendor/bundle/bin/rails"
                      echo "Shebang patched to: $(head -n 1 $TMPDIR/vendor/bundle/bin/rails)"
                    else
                      echo "ERROR: Rails executable not found in $TMPDIR/vendor/bundle/bin"
                      exit 1
                    fi
                    export PATH=${appBundlerWrapper}/bin:${effectivePkgs.yarn}/bin:${effectivePkgs.dart-sass}/bin:${effectivePkgs.nodePackages.webpack-cli}/bin:$TMPDIR/vendor/bundle/bin:${appRuby}/bin:${effectivePkgs.nodejs_20}/bin:$TMPDIR/node_modules/.bin:$PATH
                    export BUNDLE_PATH=$TMPDIR/vendor/bundle
                    export GEM_PATH=${appBundler}/lib/ruby/gems/${rubyVersion.dotted}:$GEM_HOME:$TMPDIR/vendor/bundle/ruby/3.3.0
                    export RAILS_ENV=${railsEnv}
                    ${builtins.concatStringsSep "\n" (builtins.attrValues (builtins.mapAttrs (name: value: "export ${name}=${pkgs.lib.escapeShellArg value}") extraEnv))}
                    for cmd in "${builtins.concatStringsSep "\" \"" effectiveBuildCommands}"; do
                      echo "Executing: $cmd"
                      $cmd || {
                        echo "ERROR: Failed to execute $cmd directly, trying bundle exec fallback"
                        ${appBundlerWrapper}/bin/bundle exec ''${cmd#$TMPDIR/vendor/bundle/bin/} || {
                          echo "ERROR: Fallback bundle exec also failed for $cmd"
                          exit 1
                        }
                      }
                    done
                    mkdir -p $out/app/public
                    cp -r public $out/app/public
                    if [ -f "$REDIS_PID" ]; then
                      kill $(cat $REDIS_PID)
                      sleep 1
                      rm -f $REDIS_PID $REDIS_SOCKET
                    fi
                    pg_ctl -D $PGDATA stop
        '';
        installPhase = ''
                    echo "******************************************************************"
                    echo "Entering install phase for buildRailsApp"
                    echo "******************************************************************"
                    mkdir -p $out/app/bin $out/app/.bundle
                    cp -r . $out/app
                    cat > $out/app/bin/rails-app <<'EOF'
          #!${effectivePkgs.runtimeShell}
          export GEM_HOME=/app/.nix-gems
          export GEM_PATH=${appBundler}/lib/ruby/gems/${rubyVersion.dotted}:/app/.nix-gems:/app/vendor/bundle/ruby/3.3.0
          unset RUBYLIB
          unset $(env | grep ^BUNDLE_ | cut -d= -f1)
          export BUNDLE_PATH=/app/vendor/bundle
          export BUNDLE_GEMFILE=/app/Gemfile
          export PATH=${appBundlerWrapper}/bin:/app/vendor/bundle/bin:/app/node_modules/.bin:${pkgs.yarn}/bin:${pkgs.dart-sass}/bin:${pkgs.nodejs_20}/bin:${pkgs.nodePackages.webpack-cli}/bin:$PATH
          export NODE_PATH=/app/node_modules:${pkgs.nodejs_20}/lib/node_modules:$NODE_PATH
          export RUBYOPT="-r logger"
          export XDG_DATA_DIRS=${effectivePkgs.shared-mime-info}/share:$XDG_DATA_DIRS
          export FREEDESKTOP_MIME_TYPES_PATH=${effectivePkgs.shared-mime-info}/share/mime/packages/freedesktop.org.xml
          export TZDIR=${pkgs.tzdata}/share/zoneinfo
          mkdir -p /app/.bundle
          cd /app
          exec ${ruby}/bin/ruby /app/vendor/bundle/bin/rails "$@"
          EOF
                    chmod +x $out/app/bin/rails-app
                    sed -i 's|#!/usr/bin/env ruby|#!${appRuby}/bin/ruby|' "$out/app/bin/rails-app"
        '';
      };
      bundler = appBundler;
    };

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
      rubyVersion = detectRubyVersion {inherit src;};
      ruby = effectivePkgs."ruby-${rubyVersion.dotted}" or (throw "Ruby version ${rubyVersion.dotted} not found in nixpkgs-ruby");
      gcc =
        if packageOverrides ? gcc
        then packageOverrides.gcc
        else
          (
            if gccVersion != null
            then historicalPkgs."gcc${gccVersion}"
            else pkgs.gcc
          );
      appBundlerVersion = detectBundlerVersion {inherit src;};
      appBundlerGem = bundlerGems."${appBundlerVersion}" or (throw "Unsupported bundler version: ${appBundlerVersion}. Update bundler-hashes.nix or provide custom bundlerHashes.");
      appBundler = effectivePkgs.stdenv.mkDerivation {
        name = "bundler-${appBundlerVersion}";
        buildInputs = [ruby effectivePkgs.git];
        src = effectivePkgs.fetchurl {
          url = appBundlerGem.url;
          sha256 = appBundlerGem.sha256;
        };
        dontUnpack = true;
        installPhase = ''
          export LD_LIBRARY_PATH=${effectivePkgs.postgresql}/lib:${effectivePkgs.libyaml}/lib:$LD_LIBRARY_PATH
          export HOME=$TMPDIR
          export GEM_HOME=$out/lib/ruby/gems/${rubyVersion.dotted}
          export GEM_PATH=$GEM_HOME
          export PATH=$out/bin:$PATH
          mkdir -p $GEM_HOME $out/bin
          gem install --no-document --local $src --install-dir $GEM_HOME --bindir $out/bin
          if [ -f "$out/bin/bundle" ]; then
            sed -i 's|#!/usr/bin/env ruby|#!${ruby}/bin/ruby|' "$out/bin/bundle"
          fi
        '';
      };
      appBundlerWrapper = pkgs.writeShellScriptBin "bundle" ''
        #!${pkgs.runtimeShell}
        export GEM_HOME=$TMPDIR/gems
        export GEM_PATH=${appBundler}/lib/ruby/gems/${rubyVersion.dotted}:$GEM_HOME:$TMPDIR/vendor/bundle/ruby/3.3.0
        export BUNDLE_PATH=$TMPDIR/vendor/bundle
        export BUNDLE_GEMFILE=$PWD/Gemfile
        unset RUBYLIB
        exec ${ruby}/bin/ruby ${appBundler}/bin/bundle "$@"
      '';
    in
      effectivePkgs.mkShell {
        buildInputs = with effectivePkgs; [
          ruby
          appBundler
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
          dart-sass
          nodePackages.webpack-cli
        ];
        shellHook = ''
          unset GEM_HOME GEM_PATH
          unset $(env | grep ^BUNDLE_ | cut -d= -f1)
          export HOME=$PWD/.nix-home
          mkdir -p $HOME
          export GEM_HOME=$PWD/.nix-gems
          export GEM_PATH=${appBundler}/lib/ruby/gems/${rubyVersion.dotted}:$GEM_HOME
          unset RUBYLIB
          export BUNDLE_PATH=$PWD/vendor/bundle
          export BUNDLE_GEMFILE=$PWD/Gemfile
          export BUNDLE_USER_CONFIG=$PWD/.bundle/config
          export BUNDLE_IGNORE_CONFIG=1
          export PATH=${appBundlerWrapper}/bin:${ruby}/bin:./node_modules/.bin:${effectivePkgs.yarn}/bin:${effectivePkgs.dart-sass}/bin:${effectivePkgs.nodejs_20}/bin:${effectivePkgs.nodePackages.webpack-cli}/bin:$PATH
          export NODE_PATH=./node_modules:${effectivePkgs.nodejs_20}/lib/node_modules:$NODE_PATH
          export RUBYOPT="-r logger"
          export LD_LIBRARY_PATH=${effectivePkgs.postgresql}/lib:${effectivePkgs.libyaml}/lib:$LD_LIBRARY_PATH
          export XDG_DATA_DIRS=${effectivePkgs.shared-mime-info}/share:$XDG_DATA_DIRS
          export FREEDESKTOP_MIME_TYPES_PATH=${effectivePkgs.shared-mime-info}/share/mime/packages/freedesktop.org.xml
          export TZDIR=${effectivePkgs.tzdata}/share/zoneinfo
          export REDIS_URL=redis://localhost:6379/0
          export CC=${gcc}/bin/gcc
          export CXX=${gcc}/bin/g++
          mkdir -p .nix-gems $BUNDLE_PATH/bin $PWD/.bundle
          echo "Installing bundler ${appBundlerVersion} into GEM_HOME..."
          ${ruby}/bin/gem install --no-document --local ${appBundler.src} --install-dir $GEM_HOME --bindir $BUNDLE_PATH/bin || {
            echo "Failed to install bundler ${appBundlerVersion} into GEM_HOME"
            exit 1
          }
          ${appBundlerWrapper}/bin/bundle config set --local path $BUNDLE_PATH
          ${appBundlerWrapper}/bin/bundle config set --local bin $BUNDLE_PATH/bin
          if [ -d "$BUNDLE_PATH/bin" ]; then
            export PATH=$BUNDLE_PATH/bin:$PATH
          fi
          echo "Welcome to the Rails dev shell!"
        '';
      };

    jsDevShell = {
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
      rubyVersion = detectRubyVersion {inherit src;};
      ruby = effectivePkgs."ruby-${rubyVersion.dotted}" or (throw "Ruby version ${rubyVersion.dotted} not found in nixpkgs-ruby");
      gcc =
        if packageOverrides ? gcc
        then packageOverrides.gcc
        else
          (
            if gccVersion != null
            then historicalPkgs."gcc${gccVersion}"
            else pkgs.gcc
          );
      appBundlerVersion = detectBundlerVersion {inherit src;};
      appBundlerGem = bundlerGems."${appBundlerVersion}" or (throw "Unsupported bundler version: ${appBundlerVersion}. Update bundler-hashes.nix or provide custom bundlerHashes.");
      appBundler = effectivePkgs.stdenv.mkDerivation {
        name = "bundler-${appBundlerVersion}";
        buildInputs = [ruby effectivePkgs.git];
        src = effectivePkgs.fetchurl {
          url = appBundlerGem.url;
          sha256 = appBundlerGem.sha256;
        };
        dontUnpack = true;
        installPhase = ''
          export LD_LIBRARY_PATH=${effectivePkgs.postgresql}/lib:${effectivePkgs.libyaml}/lib:$LD_LIBRARY_PATH
          export HOME=$TMPDIR
          export GEM_HOME=$out/lib/ruby/gems/${rubyVersion.dotted}
          export GEM_PATH=$GEM_HOME
          export PATH=$out/bin:$PATH
          mkdir -p $GEM_HOME $out/bin
          gem install --no-document --local $src --install-dir $GEM_HOME --bindir $out/bin
          if [ -f "$out/bin/bundle" ]; then
            sed -i 's|#!/usr/bin/env ruby|#!${ruby}/bin/ruby|' "$out/bin/bundle"
          fi
        '';
      };
      appBundlerWrapper = pkgs.writeShellScriptBin "bundle" ''
        #!${pkgs.runtimeShell}
        export GEM_HOME=$TMPDIR/gems
        export GEM_PATH=${appBundler}/lib/ruby/gems/${rubyVersion.dotted}:$GEM_HOME:$TMPDIR/vendor/bundle/ruby/3.3.0
        export BUNDLE_PATH=$TMPDIR/vendor/bundle
        export BUNDLE_GEMFILE=$PWD/Gemfile
        unset RUBYLIB
        exec ${ruby}/bin/ruby ${appBundler}/bin/bundle "$@"
      '';
    in
      effectivePkgs.mkShell {
        buildInputs = with effectivePkgs; [
          nodejs_20
          yarn
          dart-sass
          nodePackages.webpack-cli
          appBundler
          ruby
        ];
        shellHook = ''
          unset GEM_HOME GEM_PATH
          unset $(env | grep ^BUNDLE_ | cut -d= -f1)
          export HOME=$PWD/.nix-home
          mkdir -p $HOME
          export GEM_HOME=$PWD/.nix-gems
          export GEM_PATH=${appBundler}/lib/ruby/gems/${rubyVersion.dotted}:$GEM_HOME
          export BUNDLE_PATH=$PWD/vendor/bundle
          export BUNDLE_GEMFILE=$PWD/Gemfile
          export BUNDLE_USER_CONFIG=$PWD/.bundle/config
          export BUNDLE_IGNORE_CONFIG=1
          export PATH=${appBundlerWrapper}/bin:${ruby}/bin:./node_modules/.bin:${effectivePkgs.yarn}/bin:${effectivePkgs.dart-sass}/bin:${effectivePkgs.nodejs_20}/bin:${effectivePkgs.nodePackages.webpack-cli}/bin:$PATH
          export NODE_PATH=./node_modules:${effectivePkgs.nodejs_20}/lib/node_modules:$NODE_PATH
          mkdir -p .nix-gems $BUNDLE_PATH/bin $PWD/.bundle
          echo "Installing bundler ${appBundlerVersion} into GEM_HOME..."
          ${ruby}/bin/gem install --no-document --local ${appBundler.src} --install-dir $GEM_HOME --bindir $BUNDLE_PATH/bin || {
            echo "Failed to install bundler ${appBundlerVersion} into GEM_HOME"
            exit 1
          }
          ${appBundlerWrapper}/bin/bundle config set --local path $BUNDLE_PATH
          ${appBundlerWrapper}/bin/bundle config set --local bin $BUNDLE_PATH/bin
          if [ -d "$BUNDLE_PATH/bin" ]; then
            export PATH=$BUNDLE_PATH/bin:$PATH
          fi
          echo "JavaScript development shell activated"
        '';
      };
  in {
    lib.${system} = {
      inherit detectRubyVersion detectBundlerVersion buildRailsApp nixpkgsConfig mkAppDevShell;
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
      app =
        (buildRailsApp {
          inherit system nixpkgsConfig;
          src = self;
        }).app;
    };
    devShells.${system} = {
      app = mkAppDevShell {src = self;};
      jsDev = jsDevShell {src = self;};
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
    flake_version = flake_version;
  };
}
