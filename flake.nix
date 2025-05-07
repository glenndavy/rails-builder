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
    pkgs = import nixpkgs {
      inherit system;
      overlays = [nixpkgs-ruby.overlays.default];
    };

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
        else throw "Gemfile.lock not found.";
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
    }: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [nixpkgs-ruby.overlays.default];
      };
      defaultBuildInputs = with pkgs; [libyaml postgresql zlib openssl libxml2 libxslt imagemagick];
      rubyVersion = detectRubyVersion {inherit src rubyVersionSpecified;};
      ruby = pkgs."ruby-${rubyVersion.dotted}";
      bundlerVersion = detectBundlerVersion {inherit src;};
      bundlerGem = bundlerGems."${bundlerVersion}" or (throw "Unsupported bundler version: ${bundlerVersion}");
      bundler = pkgs.stdenv.mkDerivation {
        name = "bundler-${bundlerVersion}";
        buildInputs = [pkgs.git ruby];
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
        else buildCommands;
    in
      pkgs.stdenv.mkDerivation {
        name = "rails-app";
        inherit src extraBuildInputs;
        buildInputs = [ruby bundler] ++ defaultBuildInputs ++ extraBuildInputs;
        nativeBuildInputs =
          [ruby]
          ++ (
            if gemset != null && gem_strategy == "bundix" && builtins.pathExists ./gemset.nix
            then [ruby.gems]
            else []
          );
        buildPhase = ''
          export HOME=$TMPDIR
          export GEM_HOME=$TMPDIR/gems
          export GEM_PATH=${bundler}/lib/ruby/gems/${rubyVersion.dotted}:$GEM_HOME
          export PATH=${bundler}/bin:$out/app/vendor/bundle/bin:$PATH
          export BUNDLE_PATH=$out/app/vendor/bundle
          export SECRET_KEY_BASE=dummy_secret_key_for_build
          mkdir -p $GEM_HOME $out/app/vendor/bundle/bin

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
            else ''
              ls -l gemset.nix || echo 'gemset.nix not found in source'
              cat gemset.nix || echo 'Cannot read gemset.nix'
              echo "Gemset null check: ${
                if gemset != null
                then "gemset provided"
                else "gemset is null"
              }"
            ''
          }
          echo "Gemfile.lock contents:"
          cat Gemfile.lock
          echo "Checking Git index for gemset.nix:"
          git ls-files gemset.nix || echo "gemset.nix not in Git index"
          echo "Checking source directory:"
          ls -l .
          echo "Checking for gemset.nix existence:"
          if [ -f ./gemset.nix ]; then
            echo "gemset.nix exists in source"
          else
            echo "gemset.nix does not exist in source"
            exit 1
          fi

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
              ${bundler}/bin/bundle config set --local path $out/app/vendor/bundle
              ${bundler}/bin/bundle config set --local cache_path vendor/cache
              ${bundler}/bin/bundle install --local --no-cache --binstubs $out/app/vendor/bundle/bin
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
            else if gem_strategy == "bundix" && gemset != null && builtins.pathExists ./gemset.nix
            then ''
              ${bundler}/bin/bundle config set --local path $out/app/vendor/bundle
              ${bundler}/bin/bundle install --local --binstubs $out/app/vendor/bundle/bin
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
              echo "Error: Invalid gem_strategy '${gem_strategy}' or missing gemset.nix for bundix"
              exit 1
            ''
          }
          ${builtins.concatStringsSep "\n" effectiveBuildCommands}
          pg_ctl -D $PGDATA stop
        '';
        installPhase = ''
          mkdir -p $out/app
          cp -r . $out/app
        '';
      };
  in {
    lib.${system} = {
      inherit detectRubyVersion detectBundlerVersion buildRailsApp;
    };
    packages.${system}.generate-gemset = pkgs.writeShellScriptBin "generate-gemset" ''
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
      if [ ! -f gemset.nix ]; then
        echo "Error: Failed to generate gemset.nix."
        exit 1
      fi
      echo "Generated gemset.nix successfully."
    '';
    devShells.${system}.bundix = pkgs.mkShell {
      buildInputs = [pkgs.bundix];
      shellHook = ''
        echo "Run 'bundix' to generate gemset.nix."
      '';
    };
  };
}
