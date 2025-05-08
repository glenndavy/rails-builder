{
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
      _ = builtins.trace "Resolved src path: ${toString src}" null;
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

    detectBundlerVersion = { src }: let
      tracedSrc = builtins.trace "Resolved src path: ${toString src}" src;
      lockFile = "${tracedSrc}/Gemfile.lock";
      fileExists = builtins.trace "Checking if ${lockFile} exists: ${
        if builtins.pathExists lockFile
        then "yes"
        else "no"
      }" (builtins.pathExists lockFile);
      version =
        if fileExists
        then let
          rawContent = builtins.readFile lockFile;
          _rawTrace = builtins.trace "Gemfile.lock raw length: ${toString (builtins.stringLength rawContent)} characters" null;
          _contentTrace = builtins.trace "Last 50 chars of raw content: '${builtins.substring (
              if (builtins.stringLength rawContent) > 50
              then (builtins.stringLength rawContent) - 50
              else 0
            )
            50
            rawContent}'"
          null;
          allLines = builtins.split "\n" rawContent;
          lines = builtins.filter (line: builtins.typeOf line == "string" && line != "") allLines;
          lineCount = builtins.length lines;
          _linesTrace = builtins.trace "Gemfile.lock has ${toString (builtins.length allLines)} lines (after filtering: ${toString lineCount})" null;
          bundledWithIndices = builtins.filter (i: (builtins.match "[[:space:]]*BUNDLED WITH[[:space:]]*" (builtins.elemAt lines i)) != null) (builtins.genList (i: i) lineCount);
          versionLine =
            if bundledWithIndices != [] && (builtins.head bundledWithIndices) + 1 < lineCount
            then let
              idx = (builtins.head bundledWithIndices) + 1;
              line = builtins.elemAt lines idx;
              lineType = builtins.typeOf line;
              _typeTrace = builtins.trace "Version line raw: ${toString line}, type: ${lineType}" null;
            in
              if lineType == "string"
              then line
              else throw "Version line is not a string: type is ${lineType}, value is ${toString line}"
            else throw "BUNDLED WITH not found or no version line follows in Gemfile.lock.";
          versionMatch = builtins.match "[[:space:]]*([0-9]+\\.[0-9]+\\.[0-9]+(\\.[0-9]+)?)[[:space:]]*" versionLine;
          _matchTrace =
            builtins.trace "Version match result: ${
              if versionMatch == null
              then "null"
              else toString versionMatch
            }"
            null;
        in
          if versionMatch != null
          then builtins.trace "Extracted version: ${builtins.head versionMatch}" (builtins.head versionMatch)
          else throw "Could not parse bundler_version from line after BUNDLED WITH: '${versionLine}'"
        else throw "Gemfile.lock not found.";
    in
      version;

    buildRailsApp = {
      system,
      rubyVersionSpecified ? null,
      gemset ? null,
      src,
      railsEnv ? "production",
      extraEnv ? {},
      extraBuildInputs ? [],
      gem_strategy ? "vendored",
      buildCommands ? ["bundle exec rails assets:precompile"],
    }: let
      defaultBuildInputs = with pkgs; [libyaml postgresql zlib openssl libxml2 libxslt imagemagick];
      rubyVersion = detectRubyVersion { inherit src rubyVersionSpecified; };
      ruby = pkgs."ruby-${rubyVersion.dotted}";
      bundlerVersion = detectBundlerVersion { inherit src; };
      bundlerGem = bundlerGems."${bundlerVersion}" or (throw "Unsupported bundler version: ${bundlerVersion}");
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
          export GEM_HOME=$out/bundler_gems
          export TMP_BIN=$TMPDIR/bin
          mkdir -p $HOME $GEM_HOME $TMP_BIN
          gem install --no-document --local $src --install-dir $GEM_HOME --bindir $TMP_BIN
          mkdir -p $out/bin
          cp -r $TMP_BIN/* $out/bin/
          '';
      };
    in
      pkgs.stdenv.mkDerivation {
        name = "rails-app";
        inherit src extraBuildInputs;
        buildInputs = [ruby bundler] ++ defaultBuildInputs ++ extraBuildInputs;
        nativeBuildInputs = [ruby] ++ (
          if gemset != null && gem_strategy == "bundix" && builtins.pathExists ./gemset.nix
          then [ruby.gems]
          else []
        );
        buildPhase = ''
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

          mkdir -p $APP_DIR/config/initializers
          cat > $APP_DIR/config/initializers/build.rb <<EOF
          Rails.configuration.require_master_key = false if Rails.env.production?
          EOF

          cd $APP_DIR
          ${
            if gem_strategy == "vendored"
            then ''
              bundle config set --local path vendor/bundle
              ${
                if railsEnv == "production"
                then "bundle config set --local without 'development test'"
                else ""
              }
              bundle install
            ''
            else if gem_strategy == "bundix" && builtins.pathExists ./gemset.nix
            then ''
              bundle config set --local path $out/gems
              bundle install
            ''
            else ""
          }
          ${builtins.concatStringsSep "\n" buildCommands}
          pg_ctl -D $PGDATA stop
        '';
        installPhase = ''
          mkdir -p $out/app
          cp -r . $out/app
        '';
      };
  in {
    apps.${system} = {
      detectBundlerVersion = {
        type = "app";
        program = let
          version = (detectBundlerVersion { src = ./.; });
          script = pkgs.writeScriptBin "detect-bundler-version" ''
            #!${pkgs.runtimeShell}
            echo "${version}"
          '';
        in "${script}/bin/detect-bundler-version";
      };

      detectRubyVersion = {
        type = "app";
        program = let
          version = (detectRubyVersion { src = ./.; }).dotted;
          script = pkgs.writeScriptBin "detect-ruby-version" ''
            #!${pkgs.runtimeShell}
            echo "${version}"
          '';
        in "${script}/bin/detect-ruby-version";
      };
    };

    packages.${system} = {
      default = buildRailsApp {
        inherit system;
        src = ./.;
        gem_strategy = "vendored";
      };

      bundix = buildRailsApp {
        inherit system;
        src = ./.;
        gem_strategy = "bundix";
        gemset = if builtins.pathExists ./gemset.nix then import ./gemset.nix else null;
      };

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
        if [ ! -f gemset.nix ]; then
          echo "Error: Failed to generate gemset.nix."
          exit 1
        fi
        echo "Generated gemset.nix successfully."
      '';
    };

    lib.${system} = {
      inherit detectRubyVersion detectBundlerVersion;
    };

    devShells.${system} = {
      bundix = pkgs.mkShell {
        buildInputs = [pkgs.bundix];
        shellHook = ''
          echo "Run 'bundix' to generate gemset.nix."
        '';
      };
    };
  };
}
