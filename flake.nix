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

    detectRubyVersion = {
      src,
      rubyVersionSpecified ? null,
    }: let
      _ = builtins.trace "Resolved src path: ${toString src}" null;
      version =
        if rubyVersionSpecified != null
        then rubyVersionSpecified
        else if builtins.pathExists "${src}/.ruby_version"
        then builtins.replaceStrings ["ruby" "ruby-"] ["" ""] (builtins.readFile "${src}/.ruby_version")
        else throw "Missing .ruby_version file in ${src}.";
      underscored = builtins.replaceStrings ["."] ["_"] version;
    in {
      dotted = version;
      underscored = underscored;
    };

    buildRailsApp = {
      system,
      rubyVersionSpecified ? null,
      gemset ? null,
      src,
      railsEnv ? "production",
      extraEnv ? {},
      extraBuildInputs ? [],
      gem_strategy ? "vendored",
    }: let
      rubyVersion = detectRubyVersion {inherit src rubyVersionSpecified;};
      ruby = pkgs."ruby-${rubyVersion.underscored}";
      defaultBuildInputs = with pkgs; [libyaml postgresql zlib openssl libxml2 libxslt imagemagick];
    in
      pkgs.stdenv.mkDerivation {
        name = "rails-app";
        inherit src extraBuildInputs;
        buildInputs = [ruby] ++ defaultBuildInputs ++ extraBuildInputs;
        nativeBuildInputs =
          [ruby]
          ++ (
            if gemset != null && gem_strategy == "bundix"
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
          ${builtins.concatStringsSep "\n" (builtins.attrValues (builtins.mapAttrs (name: value: "export ${name}=${pkgs.lib.escapeShellArg value}") extraEnv))}
          ${
            if gem_strategy == "vendored"
            then ''
              bundle config set --local path vendor/bundle
              bundle install
            ''
            else if gem_strategy == "bundix"
            then ''
              bundle config set --local path $out/gems
              bundle install
            ''
            else throw "Invalid gem_strategy: ${gem_strategy}"
          }
        '';
        installPhase = ''
          mkdir -p $out/app
          cp -r . $out/app
        '';
      };
  in {
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
        gemset = import ./gemset.nix;
      };
      generate-gemset = pkgs.writeShellScriptBin "generate-gemset" ''
        if [ ! -f Gemfile.lock ]; then
          echo "Error: Gemfile.lock is missing."
          exit 1
        fi
        if [ ! -d vendor/cache ]; then
          echo "Error: vendor/cache is missing."
          exit 1
        fi
        ${pkgs.bundix}/bin/bundix
        if [ ! -f gemset.nix ]; then
          echo "Error: Failed to generate gemset.nix."
          exit 1
        fi
        echo "Generated gemset.nix successfully."
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
  };
}
