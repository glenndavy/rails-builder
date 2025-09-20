{
  description = "Rails app template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
    rails-builder = {
      url = "github:glenndavy/rails-builder";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-ruby,
    flake-compat,
    rails-builder,
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    overlays = [nixpkgs-ruby.overlays.default];

    mkPkgsForSystem = system: import nixpkgs {
      inherit system overlays;
      config.permittedInsecurePackages = ["openssl-1.1.1w"];
    };
    # Simple version with git info (avoiding builtins.currentTime)
    version = let
      gitRev =
        if builtins.pathExists ./.git
        then let
          headContent = builtins.readFile ./.git/HEAD;
        in builtins.substring 0 7 headContent
        else "nogit";
    in "1.0.0-${gitRev}";
    gccVersion = "latest";
    opensslVersion = "3";

    #detect ruby version
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
    #end detect ruby version

    #detect bundler version
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
    #end detect bundler version

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

      manage-postgres-script = pkgs.writeShellScriptBin "manage-postgres" (import (rails-builder + /imports/manage-postgres-script.nix) {inherit pkgs;});
      manage-redis-script = pkgs.writeShellScriptBin "manage-redis" (import (rails-builder + /imports/manage-redis-script.nix) {inherit pkgs;});
      make-rails-app-script = pkgs.writeShellScriptBin "make-rails-app" (import (rails-builder + /imports/make-rails-app-script.nix) {inherit pkgs rubyPackage bundlerVersion rubyMajorMinor;});

      builderExtraInputs =
        [
          gccPackage
          pkgs.pkg-config
          pkgs.rsync
          pkgs.bundix  # For generating gemset.nix if needed
        ]
        ++ [
          manage-postgres-script
          manage-redis-script
          make-rails-app-script
        ];

      defaultShellHook = ''
        echo "DEBUG: Shell hook for shell " >&2
        export PS1="shell:>"
        export PKG_CONFIG_PATH="${pkgs.curl.dev}/lib/pkgconfig:${pkgs.postgresql}/lib/pkgconfig"
        export LD_LIBRARY_PATH="${pkgs.curl}/lib:${pkgs.postgresql}/lib:${opensslPackage}/lib"
        unset RUBYLIB GEM_PATH
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
          export PATH=${rubyPackage}/bin:$GEM_HOME/bin:$HOME/.nix-profile/bin:$PATH
          # pausing on this, till we know we can't use the bundler package
          #${rubyPackage}/bin/gem install bundler:${bundlerVersion} --no-document
        '';

      appSrc = pkgs.stdenv.mkDerivation {
        name = "rails-app";
        src = ./.;
        nativeBuildInputs = [pkgs.rsync pkgs.coreutils pkgs.bash];
        buildInputs = universalBuildInputs;
        installPhase = ''
          echo "DEBUG: rails-app install phase start" >&2
          mkdir -p $out/app
          rsync -a --delete --include '.*' --exclude 'flake.nix' --exclude 'flake.lock' --exclude 'prepare-build.sh' . $out/app
          echo "DEBUG: Filesystem setup completed" >&2
          echo "DEBUG: rails-app install phase done" >&2
        '';
      };

      dockerImage = pkgs.dockerTools.buildLayeredImage {
        name = "rails-app-image";

        contents =
          universalBuildInputs
          ++ builderExtraInputs
          ++ [
            appSrc
            usrBinDerivation
            pkgs.goreman
            rubyPackage
            pkgs.curl
            opensslPackage
            pkgs.rsync
            pkgs.zlib
            pkgs.gosu
            pkgs.bash
            pkgs.coreutils
          ];
        config = {
          Cmd = ["${pkgs.bash}/bin/bash" "-c" "${pkgs.gosu}/bin/gosu app_user ${pkgs.goreman}/bin/goreman start web"];
          Env = [
            "BUNDLE_PATH=/app/vendor/bundle"
            "BUNDLE_GEMFILE=/app/Gemfile"
            "RAILS_ENV=production"
            "RUBYLIB=${rubyPackage}/lib/ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/site_ruby/${rubyMajorMinor}.0"
            "RUBYOPT=-I${rubyPackage}/lib/ruby/${rubyMajorMinor}.0"
            "PATH=/app/vendor/bundle/bin:${rubyPackage}/bin:/usr/local/bin:/usr/bin:/bin"
            "TZDIR=/usr/share/zoneinfo"
          ];
          User = "app_user:app_user";
          WorkingDir = "/app";
        };
        enableFakechroot = true;

        fakeRootCommands = ''
          set -x
          echo "DEBUG: Execuiting dockerImage fakeroot commands"
          mkdir -p /etc
          cat > /etc/passwd <<-EOF
          root:x:0:0::/root:/bin/bash
          app_user:x:1000:1000:App User:/app:/bin/bash
          EOF
          cat > /etc/group <<-EOF
          root:x:0:
          app_user:x:1000:
          EOF
          # Optional shadow
          cat > /etc/shadow <<-EOF
          root:*:18000:0:99999:7:::
          app_user:*:18000:0:99999:7:::
          EOF
          chown -R 1000:1000 /app
          chmod -R u+w /app
          echo "DEBUG: Done execuiting dockerImage fakeroot commands"
        '';
      };

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
          program = "${pkgs.bash}/bin/bash";
          args = ["-c" "echo 'Flake Version: ${version}'"];
        };
      };

      packages = {
        ruby = rubyPackage;
        railsPackage = appSrc;
        flakeVersion = pkgs.writeText "flake-version" "Flake Version: ${version}";
        manage-postgres = manage-postgres-script;
        manage-redis = manage-redis-script;
        make-rails-app = make-rails-app-script;
        dockerImage = dockerImage;
      };

      devShells = {
        default = pkgs.mkShell {
          buildInputs = universalBuildInputs ++ builderExtraInputs;
          shellHook = defaultShellHook;
        };
        dev = pkgs.mkShell {
          buildInputs = universalBuildInputs ++ builderExtraInputs;
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