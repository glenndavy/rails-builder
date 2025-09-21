# flake.nix
{
  description = "Rails on nix template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
    rails-builder = {
      url = "github:glenndavy/rails-builder";
      flake = true;
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-ruby,
    flake-compat,
    rails-builder,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    overlays = [nixpkgs-ruby.overlays.default];

    mkPkgsForSystem = system: import nixpkgs {
      inherit system overlays;
      config.permittedInsecurePackages = ["openssl-1.1.1w"];
    };
    # Simple version for template compatibility
    version = "1.1.5-build-rails-with-nix";
    gccVersion = "latest";
    opensslVersion = "3_2";

    # Shared detection functions
    detectRubyVersion = {src}: let
      rubyVersionFile = src + "/.ruby-version";
      gemfile = src + "/Gemfile";
      parseVersion = version: let
        trimmed = builtins.replaceStrings ["\n" "\r" " "] ["" "" ""] version;
        cleaned = builtins.replaceStrings ["ruby-" "ruby"] ["" ""] trimmed;
      in
        builtins.match "^([0-9]+\\.[0-9]+\\.[0-9]+)$" cleaned;
      fromRubyVersion =
        if builtins.pathExists rubyVersionFile
        then let
          version = builtins.readFile rubyVersionFile;
        in
          if parseVersion version != null
          then builtins.head (parseVersion version)
          else throw "Error: Invalid Ruby version in .ruby-version: ${version}"
        else throw "Error: No .ruby-version found in RAILS_ROOT";
      fromGemfile =
        if builtins.pathExists gemfile
        then let
          content = builtins.readFile gemfile;
          match = builtins.match ".*ruby ['\"]([0-9]+\\.[0-9]+\\.[0-9]+)['\"].*" content;
        in
          if match != null
          then builtins.head match
          else fromRubyVersion
        else fromRubyVersion;
    in
      fromGemfile;

    detectBundlerVersion = {src}: let
      gemfileLock = src + "/Gemfile.lock";
      gemfile = src + "/Gemfile";
      parseVersion = version: builtins.match "([0-9]+\\.[0-9]+\\.[0-9]+)" version;
      fromGemfileLock =
        if builtins.pathExists gemfileLock
        then let
          content = builtins.readFile gemfileLock;
          match = builtins.match ".*BUNDLED WITH\n   ([0-9.]+).*" content;
        in
          if match != null && parseVersion (builtins.head match) != null
          then builtins.head match
          else throw "Error: Invalid or missing Bundler version in Gemfile.lock"
        else throw "Error: No Gemfile.lock found";
      fromGemfile =
        if builtins.pathExists gemfile
        then let
          content = builtins.readFile gemfile;
          match = builtins.match ".*gem ['\"]bundler['\"], ['\"](~> )?([0-9.]+)['\"].*" content;
        in
          if match != null && parseVersion (builtins.elemAt match 1) != null
          then builtins.elemAt match 1
          else fromGemfileLock
        else fromGemfileLock;
    in
      fromGemfile;

    mkOutputsForSystem = system: let
      pkgs = mkPkgsForSystem system;
      rubyVersion = detectRubyVersion {src = ./.;};
      bundlerVersion = detectBundlerVersion {src = ./.;};
      rubyPackage = pkgs."ruby-${rubyVersion}";
      rubyVersionSplit = builtins.splitVersion rubyVersion;
      rubyMajorMinor = "${builtins.elemAt rubyVersionSplit 0}.${builtins.elemAt rubyVersionSplit 1}";

      gccPackage =
        if gccVersion == "latest"
        then pkgs.gcc
        else pkgs."gcc${gccVersion}";

      opensslPackage =
        if opensslVersion == "3_2"
        then pkgs.openssl_3
        else pkgs."openssl_${opensslVersion}";

      usrBinDerivation = pkgs.stdenv.mkDerivation {
        name = "usr-bin-env";
        buildInputs = [pkgs.coreutils];
        dontUnpack = true;
        installPhase = ''
          echo "DEBUG: usrBinDerviation install phase" >&2
          echo "DEBUG: Creating usr/bin/env symlink" >&2
          mkdir -p $out/usr/bin
          ln -sf ${pkgs.coreutils}/bin/env $out/usr/bin/env
          echo "DEBUG: usrBinDerivation completed" >&2
        '';
      };

      tzinfo = pkgs.stdenv.mkDerivation {
        name = "tzinfo";
        buildInputs = [pkgs.tzdata];
        dontUnpack = true;
        installPhase = ''
          mkdir -p $out/usr/share
          ln -sf ${pkgs.tzdata}/share/zoneinfo $out/usr/share/zoneinfo
        '';
      };

      bundler = pkgs.bundler.override {
        ruby = rubyPackage;
        version = bundlerVersion;
      };
      bundlerEnv = args:
        pkgs.bundlerEnv (args
          // {
            ruby = rubyPackage;
            bundler = bundler;
          });

      gems = bundlerEnv {
        name = "rails-gems";
        inherit rubyPackage;
        gemdir = ./.; # Points to Gemfile/Gemfile.lock, but uses gemset.nix
        gemset = import ./gemset.nix; # Generated by bundix

        # Ensure native extensions are built with proper build inputs
        buildInputs = with pkgs; [
          gccPackage
          pkg-config
          opensslPackage
          libxml2
          libxslt
          zlib
          libyaml
        ];

        # Override for gems with native extensions
        postBuild = ''
          echo "Building native extensions for gems..."
        '';
      };

      yarnHashFile =
        if builtins.pathExists ./yarn.lock
        then
          pkgs.runCommand "yarn-hash" {} ''
            ${pkgs.prefetch-yarn-deps}/bin/prefetch-yarn-deps ./yarn.lock > $out
          ''
        else pkgs.writeText "yarn-hash" "{ sha256 = \"\"; }";
      yarnHash =
        if builtins.pathExists ./yarn.lock
        then (import yarnHashFile).sha256
        else "";
      yarnOfflineCache =
        if builtins.pathExists ./yarn.lock
        then
          pkgs.fetchYarnDeps {
            yarnLock = ./yarn.lock;
            sha256 = yarnHash;
          }
        else pkgs.runCommand "empty-cache" {} "mkdir -p $out";

      nodeModules =
        if builtins.pathExists ./package.json && builtins.pathExists ./yarn.lock
        then pkgs.mkYarnPackage {
          name = "rails-node-modules";
          src = ./.; # Filters to JS dirs if needed
          yarnLock = ./yarn.lock;
          packageJSON = ./package.json;
          yarnFlags = ["--offline" "--frozen-lockfile"];
        }
        else pkgs.runCommand "empty-node-modules" {} "mkdir -p $out/lib/node_modules";

      universalBuildInputs = [
        rubyPackage
        usrBinDerivation
        tzinfo
        opensslPackage
        pkgs.libpqxx
        pkgs.sqlite
        pkgs.libxml2
        pkgs.libxslt
        pkgs.zlib
        pkgs.libyaml
        pkgs.postgresql
        pkgs.zlib
        pkgs.libyaml
        pkgs.curl
        pkgs.nodejs
      ];

      appSpecificBuildInputs = [
        gems
      ] ++ (if builtins.pathExists ./package.json then [nodeModules] else []);

      manage-postgres-script = pkgs.writeShellScriptBin "manage-postgres" (import (rails-builder + /imports/manage-postgres-script.nix) {inherit pkgs;});
      manage-redis-script = pkgs.writeShellScriptBin "manage-redis" (import (rails-builder + /imports/manage-redis-script.nix) {inherit pkgs;});
      make-rails-app-with-nix-script = pkgs.writeShellScriptBin "make-rails-app-with-nix" (import (rails-builder + /imports/make-rails-app-script.nix) {inherit pkgs rubyPackage bundlerVersion rubyMajorMinor;});

      generate-dependencies-script = pkgs.writeShellScriptBin "generate-dependencies" (import (rails-builder + /imports/generate-dependencies.nix) {inherit pkgs bundlerVersion rubyPackage;});

      fix-gemset-sha-script = pkgs.writeShellScriptBin "fix-gemset-sha" (import (rails-builder + /imports/fix-gemset-sha.nix) {inherit pkgs;});

      builderExtraInputs =
        [
          gccPackage
          pkgs.pkg-config
          pkgs.rsync
          pkgs.bundix  # For generating gemset.nix
        ]
        ++ [
          packages.manage-postgres
          packages.manage-redis
          packages.make-rails-app-with-nix
          packages.generate-dependencies
          packages.fix-gemset-sha
        ];

      defaultShellHook = ''
        echo "DEBUG: Shell hook for shell " >&2
        export PS1="shell:>"
        export PKG_CONFIG_PATH="${pkgs.curl.dev}/lib/pkgconfig:${pkgs.postgresql}/lib/pkgconfig"
        export LD_LIBRARY_PATH="${pkgs.curl}/lib:${pkgs.postgresql}/lib:${opensslPackage}/lib"
        unset RUBYLIB
        echo "DEBUG: shell hook done" >&2
      '';

      devShellHook =
        defaultShellHook
        + ''
          echo "DEBUG: builder Shell hook" >&2
          export PS1="$(pwd) railsBuild shell >"
          export NIXPKGS_ALLOW_INSECURE=1
          export RAILS_ROOT=$(pwd)
          export source=$RAILS_ROOT
          export RUBYLIB=${rubyPackage}/lib/ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/site_ruby/${rubyMajorMinor}.0
          export RUBYOPT=-I${rubyPackage}/lib/ruby/${rubyMajorMinor}.0
          export PATH=${gems}/bin:${rubyPackage}/bin:$HOME/.nix-profile/bin:$PATH
          export GEM_HOME=${gems}/lib/ruby/gems/${rubyMajorMinor}.0
          export GEM_PATH=${gems}/lib/ruby/gems/${rubyMajorMinor}.0
          export BUNDLE_PATH=${gems}/ruby/${rubyMajorMinor}/gems
          ${if builtins.pathExists ./package.json
            then "export NODE_PATH=${nodeModules}/lib/node_modules"
            else "# No package.json found, skipping NODE_PATH"}

          # Bundix and gemset tools available
          echo "🔧 Nix gem management tools available:"
          echo "   bundix              - Generate gemset.nix from Gemfile.lock"
          echo "   fix-gemset-sha      - Fix SHA mismatches in gemset.nix"
          echo "   generate-dependencies - Generate both gemset.nix and yarn dependencies"

          # pausing on this, till we know we can't use the bundler package
          #${rubyPackage}/bin/gem install bundler:${bundlerVersion} --no-document
        '';

      mkRailsBuild = import (rails-builder + "/imports/make-rails-nix-build.nix") {
        inherit pkgs rubyVersion gccVersion opensslVersion universalBuildInputs rubyPackage rubyMajorMinor gems nodeModules yarnOfflineCache gccPackage opensslPackage usrBinDerivation tzinfo defaultShellHook;
        src = ./.;
        buildRailsApp = packages.make-rails-app-with-nix; # Adjust as needed
      };

      inherit (mkRailsBuild) app shell dockerImage;

      apps = {
        detectBundlerVersion = {
          type = "app";
          program = "${pkgs.writeShellScriptBin "detectBundlerVersion" ''
            echo ${bundlerVersion}
          ''}/bin/detectBundlerVersion";
        };
        detectRubyVersion = {
          type = "app";
          program = "${pkgs.writeShellScriptBin "detectRubyVersion" ''
            echo ${rubyVersion}
          ''}/bin/detectRubyVersion";
        };
        flakeVersion = {
          type = "app";
          program = "${pkgs.writeShellScript "show-version" ''
            echo 'Flake Version: ${version}'
          ''}";
        };
        generate-dependencies = {
          type = "app";
          program = "${packages.generate-dependencies}/bin/generate-dependencies";
        };
        fix-gemset-sha = {
          type = "app";
          program = "${packages.fix-gemset-sha}/bin/fix-gemset-sha";
        };
      };

      packages = {
        ruby = rubyPackage;
        railsPackage = app;
        flakeVersion = pkgs.writeText "flake-version" "Flake Version: ${version}";
        manage-postgres = manage-postgres-script;
        manage-redis = manage-redis-script;
        make-rails-app-with-nix = make-rails-app-with-nix-script;
        generate-dependencies = generate-dependencies-script;
        fix-gemset-sha = fix-gemset-sha-script;
        dockerImage = dockerImage;
      };

      devShells = {
        bare = pkgs.mkShell {
          buildInputs = universalBuildInputs ++ builderExtraInputs;
          shellHook =
            defaultShellHook
            + ''
              export PS1="bare-shell:>"
            '';
        };
        default = pkgs.mkShell {
          buildInputs = universalBuildInputs ++ builderExtraInputs;
          shellHook = defaultShellHook;
        };
        dev = pkgs.mkShell {
          buildInputs =
            universalBuildInputs
            ++ builderExtraInputs;
          shellHook = defaultShellHook + devShellHook;
        };
      };
    in {
      inherit apps packages devShells;
    };
  in {
    apps = forAllSystems (system: (mkOutputsForSystem system).apps);
    packages = forAllSystems (system: (mkOutputsForSystem system).packages);
    devShells = forAllSystems (system: (mkOutputsForSystem system).devShells);
  };
}
