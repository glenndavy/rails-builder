# flake.nix - Generic Ruby Application Template
{
  description = "Generic Ruby application template with framework auto-detection";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
    ruby-builder = {
      url = "github:glenndavy/rails-builder";  # Will be renamed
      flake = true;
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-ruby,
    flake-compat,
    ruby-builder,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    overlays = [nixpkgs-ruby.overlays.default];

    mkPkgsForSystem = system: import nixpkgs {
      inherit system overlays;
      config.permittedInsecurePackages = ["openssl-1.1.1w"];
    };

    version = "2.2.9-ruby-template";
    gccVersion = "latest";
    opensslVersion = "3_2";

    # Import framework detection
    detectFramework = import (ruby-builder + "/imports/detect-framework.nix");

    # Shared detection functions (same as Rails template)
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
        else throw "Error: No .ruby-version found in APP_ROOT";
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
    in
      fromGemfileLock;

    mkOutputsForSystem = system: let
      pkgs = mkPkgsForSystem system;
      rubyVersion = detectRubyVersion {src = ./.;};
      bundlerVersion = detectBundlerVersion {src = ./.;};
      rubyPackage = pkgs."ruby-${rubyVersion}";
      rubyVersionSplit = builtins.splitVersion rubyVersion;
      rubyMajorMinor = "${builtins.elemAt rubyVersionSplit 0}.${builtins.elemAt rubyVersionSplit 1}";

      # Framework detection
      frameworkInfo = detectFramework {src = ./.;};
      framework = frameworkInfo.framework;

      gccPackage =
        if gccVersion == "latest"
        then pkgs.gcc
        else pkgs."gcc${gccVersion}";

      opensslPackage =
        if opensslVersion == "3_2"
        then pkgs.openssl_3
        else pkgs."openssl_${opensslVersion}";

      # Shared build inputs for all Ruby apps
      universalBuildInputs = [
        rubyPackage
        opensslPackage
        pkgs.libxml2
        pkgs.libxslt
        pkgs.zlib
        pkgs.libyaml
        pkgs.curl
      ] ++ (if frameworkInfo.needsPostgresql then [
        pkgs.libpqxx  # PostgreSQL client library
        pkgs.postgresql  # PostgreSQL tools
      ] else []) ++ (if frameworkInfo.needsMysql then [
        pkgs.libmysqlclient  # MySQL client library
        pkgs.mysql80  # MySQL tools
      ] else []) ++ (if frameworkInfo.needsSqlite then [
        pkgs.sqlite  # SQLite library
      ] else []) ++ (if frameworkInfo.hasAssets then [
        pkgs.nodejs  # Node.js for asset compilation
      ] else []);

      builderExtraInputs = [
        gccPackage
        pkgs.pkg-config
        pkgs.rsync
        pkgs.bundix  # For generating gemset.nix
      ];

      # Shared scripts (only if gems are actually present)
      manage-postgres-script = if frameworkInfo.needsPostgresql
        then pkgs.writeShellScriptBin "manage-postgres" (import (ruby-builder + /imports/manage-postgres-script.nix) {inherit pkgs;})
        else null;
      manage-redis-script = if frameworkInfo.needsRedis
        then pkgs.writeShellScriptBin "manage-redis" (import (ruby-builder + /imports/manage-redis-script.nix) {inherit pkgs;})
        else null;
      generate-dependencies-script = pkgs.writeShellScriptBin "generate-dependencies" (import (ruby-builder + /imports/generate-dependencies.nix) {inherit pkgs bundlerVersion rubyPackage;});
      fix-gemset-sha-script = pkgs.writeShellScriptBin "fix-gemset-sha" (import (ruby-builder + /imports/fix-gemset-sha.nix) {inherit pkgs;});

      # Bundler approach (traditional) - using Rails builder with framework override
      bundlerBuild = let
        railsBuild = (import (ruby-builder + "/imports/make-rails-build.nix") {inherit pkgs;}) {
          inherit rubyVersion gccVersion opensslVersion;
          src = ./.;
          buildRailsApp = pkgs.writeShellScriptBin "make-ruby-app" (import (ruby-builder + /imports/make-generic-ruby-app-script.nix) {inherit pkgs rubyPackage bundlerVersion rubyMajorMinor framework;});
        };
        # Override the app name to be framework-specific
        frameworkApp = pkgs.stdenv.mkDerivation {
          name = "${framework}-app";
          src = railsBuild.app;
          installPhase = ''
            cp -r $src $out
          '';
        };
        # Override the docker image name
        frameworkDockerImage = railsBuild.dockerImage;
      in {
        app = frameworkApp;
        shell = railsBuild.shell;
        dockerImage = frameworkDockerImage;
      };

      # Bundix approach (only if gemset.nix exists)
      bundixBuild =
        if builtins.pathExists ./gemset.nix
        then let
          bundler = pkgs.bundler.override {
            ruby = rubyPackage;
          };

          gems = (import (ruby-builder + "/imports/bundler-env-with-auto-fix.nix")) {
            inherit pkgs rubyPackage bundlerVersion;
            name = "${framework}-gems";
            gemdir = ./.;
            gemset = ./gemset.nix;
            autoFix = false;

            buildInputs = with pkgs; [
              gccPackage
              pkg-config
              opensslPackage
              libxml2
              libxslt
              zlib
              libyaml
            ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
              pkgs.darwin.apple_sdk.frameworks.CoreServices
              pkgs.darwin.apple_sdk.frameworks.Foundation
              pkgs.libiconv
            ];

            gemConfig = if pkgs.stdenv.isDarwin then {
              json = attrs: {
                buildInputs = (attrs.buildInputs or []) ++ [ pkgs.libiconv ];
              };
              bootsnap = attrs: {
                buildInputs = (attrs.buildInputs or []) ++ [ pkgs.libiconv ];
              };
              msgpack = attrs: {
                buildInputs = (attrs.buildInputs or []) ++ [ pkgs.libiconv ];
              };
            } else {};
          };

          usrBinDerivation = pkgs.stdenv.mkDerivation {
            name = "usr-bin-env";
            buildInputs = [pkgs.coreutils];
            dontUnpack = true;
            installPhase = ''
              mkdir -p $out/usr/bin
              ln -sf ${pkgs.coreutils}/bin/env $out/usr/bin/env
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
          defaultShellHook = ''
            export PKG_CONFIG_PATH="${pkgs.curl.dev}/lib/pkgconfig${if frameworkInfo.needsPostgresql then ":${pkgs.postgresql}/lib/pkgconfig" else ""}${if frameworkInfo.needsMysql then ":${pkgs.mysql80}/lib/pkgconfig" else ""}"
            export LD_LIBRARY_PATH="${pkgs.curl}/lib${if frameworkInfo.needsPostgresql then ":${pkgs.postgresql}/lib" else ""}${if frameworkInfo.needsMysql then ":${pkgs.mysql80}/lib" else ""}:${opensslPackage}/lib"
          '';

          # Inline bundix build instead of importing from ruby-builder
          rubyNixApp = pkgs.stdenv.mkDerivation {
            name = "${framework}-app";
            src = ./.;
            nativeBuildInputs =
              [pkgs.rsync pkgs.coreutils pkgs.bash rubyPackage gems]
              ++ (if frameworkInfo.hasAssets then [pkgs.nodejs] else [])
              ++ (
                if builtins.pathExists (./. + "/yarn.lock")
                then [pkgs.yarnConfigHook pkgs.yarnInstallHook]
                else []
              );
            buildInputs = universalBuildInputs;

            preConfigure = ''
              export HOME=$PWD
              ${if frameworkInfo.hasAssets then ''
              if [ -f ./yarn.lock ]; then
               yarn config --offline set yarn-offline-mirror ${pkgs.runCommand "empty-cache" {} "mkdir -p $out"}
              fi'' else ""}
            '';

            buildPhase = ''
              export HOME=$PWD
              export source=$PWD
              
              ${if frameworkInfo.hasAssets then ''
              if [ -f ./yarn.lock ]; then
                yarn install ${toString ["--offline" "--frozen-lockfile"]}
              fi'' else ""}
              
              mkdir -p vendor/bundle/ruby/${rubyMajorMinor}.0
              # Copy gems from bundlerEnv to vendor for compatibility
              cp -r ${gems}/lib/ruby/gems/${rubyMajorMinor}.0/* vendor/bundle/ruby/${rubyMajorMinor}.0/

              # Set up environment for direct gem access (no bundle exec needed)
              export GEM_HOME=${gems}/lib/ruby/gems/${rubyMajorMinor}.0
              export GEM_PATH=${gems}/lib/ruby/gems/${rubyMajorMinor}.0
              export PATH=${gems}/bin:${rubyPackage}/bin:$PATH

              # Framework-specific asset compilation
              ${if framework == "rails" then ''
                rails assets:precompile
              '' else if framework == "hanami" then ''
                if [ -f bin/hanami ]; then
                  hanami assets compile || true
                fi
              '' else if frameworkInfo.hasAssets then ''
                # For other frameworks, try basic asset compilation if rake task exists
                if [ -f Rakefile ] && rake -T | grep -q assets; then
                  rake assets:precompile || true
                fi
              '' else ""}
            '';
            
            installPhase = ''
              mkdir -p $out/app
              rsync -a --delete --include '.*' --exclude 'flake.nix' --exclude 'flake.lock' --exclude 'prepare-build.sh' . $out/app
            '';
          };
          
          rubyNixShell = pkgs.mkShell {
            buildInputs =
              universalBuildInputs
              ++ [
                gccPackage
                pkgs.pkg-config
                pkgs.rsync
              ] ++ (if frameworkInfo.hasAssets then [pkgs.nodejs] else [])
              ++ (if pkgs.stdenv.isLinux then [pkgs.gosu] else []);

            shellHook = defaultShellHook;
          };
          
          rubyNixDockerImage = pkgs.dockerTools.buildLayeredImage {
            name = "${framework}-app-image";
            contents =
              universalBuildInputs
              ++ [
                rubyNixApp
                gems
                usrBinDerivation
                rubyPackage
                pkgs.curl
                opensslPackage
                pkgs.rsync
                pkgs.zlib
                pkgs.bash
                pkgs.coreutils
              ] ++ (if frameworkInfo.hasAssets then [pkgs.nodejs] else [])
              ++ (if pkgs.stdenv.isLinux then [pkgs.gosu pkgs.goreman] else []);
            enableFakechroot = !pkgs.stdenv.isDarwin;
            fakeRootCommands = ''
              mkdir -p /etc
              cat > /etc/passwd <<-EOF
              root:x:0:0::/root:/bin/bash
              app_user:x:1000:1000:App User:/app:/bin/bash
              EOF
              cat > /etc/group <<-EOF
              root:x:0:
              app_user:x:1000:
              EOF
              cat > /etc/shadow <<-EOF
              root:*:18000:0:99999:7:::
              app_user:*:18000:0:99999:7:::
              EOF
              chown -R 1000:1000 /app
              chmod -R u+w /app
            '';
            config = {
              Cmd = ["${pkgs.bash}/bin/bash" "-c" "${if pkgs.stdenv.isLinux then "${pkgs.gosu}/bin/gosu app_user " else ""}${
                if frameworkInfo.isWebApp then 
                  if framework == "rails" then "rails server -b 0.0.0.0"
                  else if framework == "hanami" then "hanami server"
                  else "rackup -o 0.0.0.0"
                else "ruby -v"
              }"];
              Env = [
                "BUNDLE_PATH=/app/vendor/bundle"
                "BUNDLE_GEMFILE=/app/Gemfile"
                "GEM_PATH=/app/vendor/bundle/ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/gems/${rubyMajorMinor}.0:/app/vendor/bundle/ruby/${rubyMajorMinor}.0/bundler/gems"
                "RAILS_ENV=production"
                "RUBYLIB=${rubyPackage}/lib/ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/site_ruby/${rubyMajorMinor}.0"
                "RUBYOPT=-I${rubyPackage}/lib/ruby/${rubyMajorMinor}.0"
                "PATH=/app/vendor/bundle/bin:${rubyPackage}/bin:/usr/local/bin:/usr/bin:/bin"
                "TZDIR=/usr/share/zoneinfo"
              ];
              User = "app_user:app_user";
              WorkingDir = "/app";
            };
          };

          railsNixBuild = {
            app = rubyNixApp;
            shell = rubyNixShell;
            dockerImage = rubyNixDockerImage;
          };
          # Use the inline bundix build we created above
        in railsNixBuild
        else null;

      # Shared shell hook
      defaultShellHook = ''
        export PS1="${framework}-shell:>"
        export PKG_CONFIG_PATH="${pkgs.curl.dev}/lib/pkgconfig${if frameworkInfo.needsPostgresql then ":${pkgs.postgresql}/lib/pkgconfig" else ""}${if frameworkInfo.needsMysql then ":${pkgs.mysql80}/lib/pkgconfig" else ""}"
        export LD_LIBRARY_PATH="${pkgs.curl}/lib${if frameworkInfo.needsPostgresql then ":${pkgs.postgresql}/lib" else ""}${if frameworkInfo.needsMysql then ":${pkgs.mysql80}/lib" else ""}:${opensslPackage}/lib"
        unset RUBYLIB
      '';

      packages = {
        ruby = rubyPackage;
        flakeVersion = pkgs.writeText "flake-version" "Flake Version: ${version}";
        generate-dependencies = generate-dependencies-script;
        fix-gemset-sha = fix-gemset-sha-script;

        # Bundler approach packages
        package-with-bundler = bundlerBuild.app;
        docker-with-bundler = bundlerBuild.dockerImage;
      } // (if frameworkInfo.needsPostgresql && manage-postgres-script != null then {
        manage-postgres = manage-postgres-script;
      } else {}) // (if frameworkInfo.needsRedis && manage-redis-script != null then {
        manage-redis = manage-redis-script;
      } else {}) // (if bundixBuild != null then {
        # Bundix approach packages (only if gemset.nix exists)
        package-with-bundix = bundixBuild.app;
        docker-with-bundix = bundixBuild.dockerImage;
      } else {});

      devShells = {
        # Default shell
        default = pkgs.mkShell {
          buildInputs = universalBuildInputs ++ builderExtraInputs ++ (builtins.filter (x: x != null) [ manage-postgres-script manage-redis-script ]);
          shellHook = defaultShellHook + ''
            echo "🔧 ${framework} application detected"
            echo "   Framework: ${framework}"
            echo "   Entry point: ${frameworkInfo.entryPoint or "auto-detected"}"
            echo "   Web app: ${if frameworkInfo.isWebApp then "yes" else "no"}"
            echo "   Has assets: ${if frameworkInfo.hasAssets then "yes (${frameworkInfo.assetPipeline or "unknown"})" else "no"}"
            echo "   Database: ${if frameworkInfo.needsPostgresql then "PostgreSQL" else if frameworkInfo.needsMysql then "MySQL" else if frameworkInfo.needsSqlite then "SQLite" else "none detected"}"
            echo "   Cache: ${if frameworkInfo.needsRedis then "Redis" else if frameworkInfo.needsMemcached then "Memcached" else "none detected"}"
          '';
        };

        # Traditional bundler approach
        with-bundler = pkgs.mkShell {
          buildInputs = universalBuildInputs ++ builderExtraInputs ++ (builtins.filter (x: x != null) [ manage-postgres-script manage-redis-script ]);
          shellHook = defaultShellHook + ''
            export PS1="$(pwd) bundler-shell >"
            export APP_ROOT=$(pwd)

            # Bundle isolation - same as build scripts
            export BUNDLE_PATH=$APP_ROOT/vendor/bundle
            export BUNDLE_GEMFILE=$PWD/Gemfile
            export PATH=$BUNDLE_PATH/bin:$APP_ROOT/bin:${rubyPackage}/bin:$PATH

            echo "🔧 Traditional bundler environment for ${framework}:"
            echo "   bundle install  - Install gems to ./vendor/bundle"
            echo "   bundle exec     - Run commands with bundler"
            ${if frameworkInfo.isWebApp then ''
            echo "   Start server:   - bundle exec ${if framework == "rails" then "rails s" else if framework == "hanami" then "hanami server" else "rackup"}"
            '' else ''
            echo "   Run app:        - bundle exec ruby your_script.rb"
            ''}
            echo "   Gems isolated in: ./vendor/bundle"
          '';
        };
      } // {
        # Bundix approach shell - with bootstrap fallback for hash mismatches
        with-bundix = let
          # Create bundler with correct version for dependency management
          bundlerPackage = pkgs.bundler.override {
            ruby = rubyPackage;
          };

          # Try to create bundlerEnv, fall back to bootstrap if it fails
          bundlerEnvResult = builtins.tryEval ((import (ruby-builder + "/imports/bundler-env-with-auto-fix.nix")) {
            inherit pkgs rubyPackage bundlerVersion;
            name = "${framework}-bundix-env";
            gemdir = ./.;
            gemset = if builtins.pathExists ./gemset.nix then ./gemset.nix else null;
            autoFix = false;

            # Enhanced build inputs for native extensions
            buildInputs = with pkgs; [
              gccPackage
              pkg-config
              opensslPackage
              libxml2
              libxslt
              zlib
              libyaml
            ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
              pkgs.darwin.apple_sdk.frameworks.CoreServices
              pkgs.darwin.apple_sdk.frameworks.Foundation
              pkgs.libiconv
            ];

            # Darwin-specific gem overrides for problematic native extensions
            gemConfig = if pkgs.stdenv.isDarwin then {
              json = attrs: {
                buildInputs = (attrs.buildInputs or []) ++ [ pkgs.libiconv ];
              };
              bootsnap = attrs: {
                buildInputs = (attrs.buildInputs or []) ++ [ pkgs.libiconv ];
              };
              msgpack = attrs: {
                buildInputs = (attrs.buildInputs or []) ++ [ pkgs.libiconv ];
              };
            } else {};
          });

          # Use bundlerEnv if successful, otherwise bootstrap environment
          bundlerEnv = if bundlerEnvResult.success then bundlerEnvResult.value else pkgs.buildEnv {
            name = "${framework}-bundix-bootstrap";
            paths = [ bundlerPackage rubyPackage pkgs.bundix ];
          };
        in pkgs.mkShell {
          # Use bundlerEnv as primary buildInput for proper closure
          buildInputs = [
            bundlerEnv
            bundlerPackage   # Correct bundler version for dependency management
            rubyPackage      # Same Ruby version as bundlerEnv
            pkgs.bundix      # For regenerating gemset.nix
            pkgs.git
            pkgs.rsync
          ] ++ (builtins.filter (x: x != null) [ manage-postgres-script manage-redis-script ])
          ++ (pkgs.lib.optionals frameworkInfo.needsPostgresql [ pkgs.postgresql ])
          ++ (pkgs.lib.optionals frameworkInfo.needsRedis [ pkgs.redis ])
          ++ (pkgs.lib.optionals frameworkInfo.hasAssets [ pkgs.nodejs ]);

          shellHook = defaultShellHook + ''
            export APP_ROOT=$(pwd)

            ${if bundlerEnvResult.success then ''
              # Normal mode: bundlerEnv loaded successfully
              export PS1="$(pwd) bundix-shell >"

              # Use bundlerEnv Ruby and gems - proper closure
              export RUBYLIB=${bundlerEnv}/lib/ruby/site_ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/site_ruby/${rubyMajorMinor}.0
              export RUBYOPT=-I${bundlerEnv}/lib/ruby/site_ruby/${rubyMajorMinor}.0

              # Proper gem paths from bundlerEnv closure
              export GEM_HOME=${bundlerEnv}/lib/ruby/gems/${rubyMajorMinor}.0
              export GEM_PATH=${bundlerEnv}/lib/ruby/gems/${rubyMajorMinor}.0

              # Binstubs from bundlerEnv + bundler + Ruby binaries
              export PATH=${bundlerEnv}/bin:${bundlerPackage}/bin:${rubyPackage}/bin:$PATH

              # Unset conflicting bundle environment
              unset BUNDLE_PATH BUNDLE_GEMFILE

              echo "🔧 Nix bundlerEnv environment for ${framework}:"
              ${if frameworkInfo.isWebApp then ''
              echo "   Start server:   - ${if framework == "rails" then "rails s" else if framework == "hanami" then "hanami server" else "rackup"} (direct, no bundle exec)"
              '' else ''
              echo "   Run app:        - ruby your_script.rb (direct, no bundle exec)"
              ''}
              echo "   gem list        - Show installed gems from Nix closure"
              echo ""
              echo "💎 Gem Environment:"
              echo "   Gems: Nix closure from gemset.nix"
              echo "   Ruby: ${rubyPackage.version} (same as bundlerEnv)"
              echo "   Bundler: ${bundlerVersion} (correct version for Gemfile.lock)"
              echo "   Framework: ${framework} (auto-detected)"
              echo "   GEM_HOME: ${bundlerEnv}/lib/ruby/gems/${rubyMajorMinor}.0"
              echo "   No bundle exec needed - direct gem access"
            '' else ''
              # Bootstrap mode: bundlerEnv failed, providing bundix to fix hashes
              export PS1="$(pwd) bundix-bootstrap >"
              export PATH=${bundlerPackage}/bin:${rubyPackage}/bin:${pkgs.bundix}/bin:$PATH

              echo "⚠️  BOOTSTRAP MODE: gemset.nix has hash mismatches"
              echo ""
              echo "🔧 Fix gemset.nix hashes by running:"
              echo "   bundix          - Regenerate gemset.nix with correct hashes"
              echo "   exit            - Exit this shell"
              echo "   nix develop .#with-bundix  - Re-enter shell (will use fixed gemset.nix)"
              echo ""
              echo "💎 Bootstrap Environment:"
              echo "   Ruby: ${rubyPackage.version} (same as target bundlerEnv)"
              echo "   Bundler: Available for dependency management"
              echo "   Bundix: Available to regenerate gemset.nix"
              echo "   Framework: ${framework} (auto-detected)"
            ''}

            echo ""
            echo "📦 Dependency Management:"
            echo "   bundle lock     - Update Gemfile.lock"
            echo "   bundle add gem  - Add new gem to Gemfile"
            echo "   bundix          - Regenerate gemset.nix from Gemfile.lock"
            echo ""
            ${if frameworkInfo.needsPostgresql || frameworkInfo.needsRedis then ''
            echo "🗄️ Database & Services:"
            ${if frameworkInfo.needsPostgresql then ''
            echo "   manage-postgres start - Start PostgreSQL server"
            echo "   manage-postgres help  - Show PostgreSQL connection info"
            '' else ""}
            ${if frameworkInfo.needsRedis then ''
            echo "   manage-redis start    - Start Redis server"
            '' else ""}
            '' else ""}
          '';
        };
      };

      apps = {
        detectFramework = {
          type = "app";
          program = "${pkgs.writeShellScriptBin "detectFramework" ''
            echo "Framework: ${framework}"
            echo "Is web app: ${if frameworkInfo.isWebApp then "yes" else "no"}"
            echo "Has assets: ${if frameworkInfo.hasAssets then "yes (${frameworkInfo.assetPipeline or "unknown"})" else "no"}"
            echo "Entry point: ${frameworkInfo.entryPoint or "auto-detected"}"
            echo "Database gems detected:"
            echo "  PostgreSQL (pg): ${if frameworkInfo.needsPostgresql then "yes" else "no"}"
            echo "  MySQL (mysql2): ${if frameworkInfo.needsMysql then "yes" else "no"}"
            echo "  SQLite (sqlite3): ${if frameworkInfo.needsSqlite then "yes" else "no"}"
            echo "Cache gems detected:"
            echo "  Redis: ${if frameworkInfo.needsRedis then "yes" else "no"}"
            echo "  Memcached: ${if frameworkInfo.needsMemcached then "yes" else "no"}"
          ''}/bin/detectFramework";
        };
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
          program = "${generate-dependencies-script}/bin/generate-dependencies";
        };
        fix-gemset-sha = {
          type = "app";
          program = "${fix-gemset-sha-script}/bin/fix-gemset-sha";
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