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

    detectRubyVersion = { src, rubyVersionSpecified ? null }:
      let
        version = if rubyVersionSpecified != null
                  then rubyVersionSpecified
                  else if builtins.pathExists "${src}/.ruby_version"
                  then builtins.replaceStrings ["ruby" "ruby-"] ["" ""] (builtins.readFile "${src}/.ruby_version")
                  else throw "Missing .ruby_version file in ${src}.";
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

    buildRailsApp = { system, rubyVersionSpecified ? null, gemset ? null, src, railsEnv ? "production", extraEnv ? {}, extraBuildInputs ? [] }:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ nixpkgs-ruby.overlays.default ];
        };
        rubyVersion = detectRubyVersion { inherit src rubyVersionSpecified; };
        ruby = pkgs."ruby-${rubyVersion.underscored}";
        defaultBuildInputs = with pkgs; [ libyaml postgresql zlib openssl libxml2 libxslt imagemagick ];
      in
      pkgs.stdenv.mkDerivation {
        name = "rails-app";
        inherit src extraBuildInputs;
        buildInputs = [ ruby ] ++ defaultBuildInputs ++ extraBuildInputs;
        nativeBuildInputs = [ ruby ] ++ (if gemset != null then [ ruby.gems ] else []);
        buildPhase = ''
          export APP_DIR=$TMPDIR/app
          mkdir -p $APP_DIR
          # ... your buildPhase logic ...
        '';
        installPhase = ''
          mkdir -p $out/app
          cp -r $APP_DIR/. $out/app
        '';
      };
  in
  forAllSystems (system:
  let
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ nixpkgs-ruby.overlays.default ];
    };
  in
  {
    lib = {
      inherit detectRubyVersion detectBundlerVersion buildRailsApp;
    };
    packages.${system} = {
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
      # Default package for building a Rails app with vendored gems
      default = buildRailsApp {
        inherit system;
        src = ./.;
        gem_strategy = "vendored";
      };
    };
    devShells.${system} = {
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
          # ... rest of shellHook ...
        '';
      };
      bundix = pkgs.mkShell {
        buildInputs = [ pkgs.bundix ];
        shellHook = ''
          echo "Run 'bundix --local' to generate gemset.nix."
        '';
      };
    };
  });
}
