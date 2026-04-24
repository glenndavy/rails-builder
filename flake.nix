# In rails-builder flake.nix
{
  description = "Generic Rails builder flake";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
    # Custom bundix fork with fixes
    bundix-src.url = "github:glenndavy/bundix";
    bundix-src.flake = false;
    # Optional: override with --override-input src path:/path/to/your/project
    src.url = "path:.";
    src.flake = false;
  };
  outputs = {
    self,
    nixpkgs,
    nixpkgs-ruby,
    bundix-src,
    src,
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    # Simple version for compatibility - can be overridden with --impure for git info
    version = "3.17.69";
    forAllSystems = nixpkgs.lib.genAttrs systems;
    overlays = [nixpkgs-ruby.overlays.default];

    mkPkgsForSystem = system: import nixpkgs {inherit system overlays;};

    # Build custom bundix from glenndavy/bundix
    mkBundixForSystem = system: let
      pkgs = mkPkgsForSystem system;
    in
      pkgs.callPackage bundix-src {};
    mkLibForSystem = system: let
      pkgs = mkPkgsForSystem system;
      mkRailsBuild = import ./imports/make-rails-build.nix {inherit pkgs;};
      mkRailsNixBuild = import ./imports/make-rails-nix-build.nix {inherit pkgs;};
      versionDetection = import ./imports/detect-versions.nix;

      # Custom bundlerEnv that supports vendor/cache gems
      customBundlerEnv = pkgs.callPackage ./imports/bundler-env {};

      # High-level helper to build Rails packages with all correct configuration
      # Usage: rails-builder.lib.${system}.mkRailsPackage { inherit pkgs; src = ./.; }
      # Note: Automatically applies nixpkgs-ruby overlay to pkgs for ruby version packages
      mkRailsPackage = args:
        import ./imports/mk-rails-package.nix (args
          // {
            nixpkgsRubyOverlay = nixpkgs-ruby.overlays.default;
            railsBuilderVersion = version;
          });
    in {
      inherit mkRailsBuild mkRailsNixBuild customBundlerEnv mkRailsPackage;
      inherit (versionDetection) detectRubyVersion detectBundlerVersion detectNodeVersion detectTailwindVersion;
      version = version;
    };

    # Create tests for each system
    mkTestsForSystem = system: let
      pkgs = mkPkgsForSystem system;
      lib = mkLibForSystem system;
      versionDetection = import ./imports/detect-versions.nix;
      detectFramework = import ./imports/detect-framework.nix;

      # Fixtures as plain paths (required for builtins.readFile/pathExists)
      railsFixture = ./tests/fixtures/rails-app;
      sinatraFixture = ./tests/fixtures/sinatra-app;
      rackFixture = ./tests/fixtures/rack-app;
      plainRubyFixture = ./tests/fixtures/plain-ruby;

      # Test version detection against fixtures
      testVersionDetection = let
        railsRuby = versionDetection.detectRubyVersion {src = railsFixture;};
        railsBundler = versionDetection.detectBundlerVersion {src = railsFixture;};
        railsTailwind = versionDetection.detectTailwindVersion {src = railsFixture;};
        plainRuby = versionDetection.detectRubyVersion {src = plainRubyFixture;};
        plainBundler = versionDetection.detectBundlerVersion {src = plainRubyFixture;};
        plainTailwind = versionDetection.detectTailwindVersion {src = plainRubyFixture;};
      in
        pkgs.stdenv.mkDerivation {
          name = "test-version-detection";
          dontUnpack = true;
          buildPhase = ''
            echo "Testing version detection..."

            test "${railsRuby}" = "3.3.0" || { echo "FAIL: rails ruby expected 3.3.0, got ${railsRuby}"; exit 1; }
            echo "ok - Rails ruby version: ${railsRuby}"

            test "${railsBundler}" = "2.5.22" || { echo "FAIL: rails bundler expected 2.5.22, got ${railsBundler}"; exit 1; }
            echo "ok - Rails bundler version: ${railsBundler}"

            test "${railsTailwind}" = "4.1.18" || { echo "FAIL: rails tailwind expected 4.1.18, got ${railsTailwind}"; exit 1; }
            echo "ok - Rails tailwind version: ${railsTailwind}"

            test "${plainRuby}" = "3.1.0" || { echo "FAIL: plain ruby expected 3.1.0, got ${plainRuby}"; exit 1; }
            echo "ok - Plain ruby version: ${plainRuby}"

            test "${plainBundler}" = "2.4.0" || { echo "FAIL: plain bundler expected 2.4.0, got ${plainBundler}"; exit 1; }
            echo "ok - Plain bundler version: ${plainBundler}"

            test "${builtins.toJSON plainTailwind}" = "null" || { echo "FAIL: plain tailwind expected null"; exit 1; }
            echo "ok - Plain tailwind version: null"
          '';
          installPhase = ''
            mkdir -p $out
            echo "Version detection tests passed" > $out/result
          '';
        };

      # Test framework and dependency detection against fixtures
      testFrameworkDetection = let
        railsInfo = detectFramework {src = railsFixture;};
        sinatraInfo = detectFramework {src = sinatraFixture;};
        rackInfo = detectFramework {src = rackFixture;};
        plainInfo = detectFramework {src = plainRubyFixture;};
      in
        pkgs.stdenv.mkDerivation {
          name = "test-framework-detection";
          dontUnpack = true;
          buildPhase = ''
            echo "Testing framework detection..."

            test "${railsInfo.framework}" = "rails" || { echo "FAIL: expected rails, got ${railsInfo.framework}"; exit 1; }
            echo "ok - Rails framework detected"

            test "${builtins.toJSON railsInfo.needsPostgresql}" = "true" || { echo "FAIL: rails should need postgresql"; exit 1; }
            echo "ok - Rails needs PostgreSQL"

            test "${builtins.toJSON railsInfo.needsRedis}" = "true" || { echo "FAIL: rails should need redis"; exit 1; }
            echo "ok - Rails needs Redis"

            test "${builtins.toJSON railsInfo.needsTailwindcss}" = "true" || { echo "FAIL: rails should need tailwindcss"; exit 1; }
            echo "ok - Rails needs Tailwind CSS"

            test "${sinatraInfo.framework}" = "sinatra" || { echo "FAIL: expected sinatra, got ${sinatraInfo.framework}"; exit 1; }
            echo "ok - Sinatra framework detected"

            test "${builtins.toJSON sinatraInfo.needsSqlite}" = "true" || { echo "FAIL: sinatra should need sqlite"; exit 1; }
            echo "ok - Sinatra needs SQLite"

            test "${rackInfo.framework}" = "rack" || { echo "FAIL: expected rack, got ${rackInfo.framework}"; exit 1; }
            echo "ok - Rack framework detected"

            test "${plainInfo.framework}" = "ruby" || { echo "FAIL: expected ruby, got ${plainInfo.framework}"; exit 1; }
            echo "ok - Plain Ruby detected"
          '';
          installPhase = ''
            mkdir -p $out
            echo "Framework detection tests passed" > $out/result
          '';
        };

      # Test template is valid and has required structure
      testTemplateEval = pkgs.stdenv.mkDerivation {
        name = "test-template-eval";
        src = ./.;
        buildPhase = ''
          echo "Testing template validity..."

          if [ ! -f templates/universal/flake.nix ]; then
            echo "FAIL: universal template missing"
            exit 1
          fi
          echo "ok - Universal template exists"

          if grep -q 'description' templates/universal/flake.nix && \
             grep -q 'inputs' templates/universal/flake.nix && \
             grep -q 'outputs' templates/universal/flake.nix; then
            echo "ok - Template has required structure (description, inputs, outputs)"
          else
            echo "FAIL: template missing required structure"
            exit 1
          fi
        '';
        installPhase = ''
          mkdir -p $out
          echo "Template evaluation tests passed" > $out/result
        '';
      };

      # Test mkRailsPackage evaluation (evaluation-only, no build)
      testMkRailsPackage = let
        railsBuild = lib.mkRailsPackage {
          inherit pkgs;
          src = railsFixture;
        };
      in
        pkgs.stdenv.mkDerivation {
          name = "test-mk-rails-package";
          dontUnpack = true;
          buildPhase = ''
            echo "Testing mkRailsPackage evaluation..."

            test "${railsBuild.detected.rubyVersion}" = "3.3.0" || { echo "FAIL: rubyVersion expected 3.3.0"; exit 1; }
            echo "ok - detected.rubyVersion = 3.3.0"

            test "${railsBuild.detected.bundlerVersion}" = "2.5.22" || { echo "FAIL: bundlerVersion expected 2.5.22"; exit 1; }
            echo "ok - detected.bundlerVersion = 2.5.22"

            test "${railsBuild.detected.tailwindVersion}" = "4.1.18" || { echo "FAIL: tailwindVersion expected 4.1.18"; exit 1; }
            echo "ok - detected.tailwindVersion = 4.1.18"

            test "${railsBuild.detected.framework}" = "rails" || { echo "FAIL: framework expected rails"; exit 1; }
            echo "ok - detected.framework = rails"

            test "${builtins.toJSON railsBuild.detected.needsPostgresql}" = "true" || { echo "FAIL: needsPostgresql expected true"; exit 1; }
            echo "ok - detected.needsPostgresql = true"

            test "${builtins.toJSON railsBuild.detected.needsRedis}" = "true" || { echo "FAIL: needsRedis expected true"; exit 1; }
            echo "ok - detected.needsRedis = true"

            test "${builtins.toJSON (builtins.hasAttr "app" railsBuild)}" = "true" || { echo "FAIL: missing app attr"; exit 1; }
            echo "ok - railsBuild has 'app' attribute"

            test "${builtins.toJSON (builtins.hasAttr "detected" railsBuild)}" = "true" || { echo "FAIL: missing detected attr"; exit 1; }
            echo "ok - railsBuild has 'detected' attribute"

            test "${builtins.toJSON (builtins.hasAttr "gems" railsBuild)}" = "true" || { echo "FAIL: missing gems attr"; exit 1; }
            echo "ok - railsBuild has 'gems' attribute"

            test "${builtins.toJSON (builtins.hasAttr "rubyPackage" railsBuild)}" = "true" || { echo "FAIL: missing rubyPackage attr"; exit 1; }
            echo "ok - railsBuild has 'rubyPackage' attribute"

            test "${builtins.toJSON (builtins.hasAttr "bundlerPackage" railsBuild)}" = "true" || { echo "FAIL: missing bundlerPackage attr"; exit 1; }
            echo "ok - railsBuild has 'bundlerPackage' attribute"
          '';
          installPhase = ''
            mkdir -p $out
            echo "mkRailsPackage evaluation tests passed" > $out/result
          '';
        };

      # Combined test runner
      runAllTests = pkgs.stdenv.mkDerivation {
        name = "run-all-tests";
        dontUnpack = true;
        buildInputs = [
          testVersionDetection
          testFrameworkDetection
          testTemplateEval
          testMkRailsPackage
        ];
        buildPhase = ''
          echo "Running all tests for ${system}..."

          echo "1. Version detection tests..."
          cat ${testVersionDetection}/result

          echo "2. Framework detection tests..."
          cat ${testFrameworkDetection}/result

          echo "3. Template evaluation tests..."
          cat ${testTemplateEval}/result

          echo "4. mkRailsPackage evaluation tests..."
          cat ${testMkRailsPackage}/result

          echo "All tests completed successfully!"
        '';
        installPhase = ''
          mkdir -p $out
          echo "All tests passed for ${system}" > $out/result
        '';
      };
    in {
      inherit testVersionDetection testFrameworkDetection testTemplateEval testMkRailsPackage runAllTests;
    };
  in {
    # Export version at top level for easy access from templates
    inherit version;

    lib = forAllSystems mkLibForSystem;

    # Export custom bundix package for use by template
    packages = forAllSystems (system: {
      bundix = mkBundixForSystem system;
    });

    # Add test outputs
    checks = forAllSystems mkTestsForSystem;

    # Apps
    apps = forAllSystems (system: let
      pkgs = mkPkgsForSystem system;
      customBundix = mkBundixForSystem system;
      fix-gemset-sha-script = pkgs.writeShellScriptBin "fix-gemset-sha" (import ./imports/fix-gemset-sha.nix {inherit pkgs;});
      generate-gemset-for-script = pkgs.writeShellScriptBin "generate-gemset-for" (import ./imports/generate-gemset-for.nix {
        inherit pkgs;
        bundixPackage = customBundix;
        defaultRubyPackage = pkgs.ruby;
      });
    in {
      flakeVersion = {
        type = "app";
        program = "${pkgs.writeShellScript "show-version" ''
          echo 'Flake Version: ${version}'
        ''}";
      };

      # Fix SHA mismatches in gemset.nix
      # Usage: nix run github:glenndavy/rails-builder#fix-gemset-sha
      fix-gemset-sha = {
        type = "app";
        program = "${fix-gemset-sha-script}/bin/fix-gemset-sha";
      };

      # Generate gemset.nix for an external app source (orchestrator pattern)
      # Usage: nix run github:glenndavy/rails-builder#generate-gemset-for -- /path/to/app
      # Usage: nix run github:glenndavy/rails-builder#generate-gemset-for -- /path/to/app -o ./apps/my-app/gemset.nix
      generate-gemset-for = {
        type = "app";
        program = "${generate-gemset-for-script}/bin/generate-gemset-for";
      };
    });

    templates = {
      # 🚀 Universal Template (single source of truth)
      universal = {
        path = ./templates/universal;
        description = "Universal Ruby application template with smart dependency detection (Rails, Hanami, Sinatra, Rack, Ruby)";
      };

      # 🎯 Framework-specific aliases (all point to universal template)
      rails = {
        path = ./templates/universal;
        description = "Rails application template with smart dependency detection";
      };
      hanami = {
        path = ./templates/universal;
        description = "Hanami application template with smart dependency detection";
      };
      sinatra = {
        path = ./templates/universal;
        description = "Sinatra application template with smart dependency detection";
      };
      rack = {
        path = ./templates/universal;
        description = "Rack application template with smart dependency detection";
      };
      ruby = {
        path = ./templates/universal;
        description = "Generic Ruby application template with framework auto-detection";
      };

      # 📦 Versioned templates for cache-busting
      universal-v3-0-0 = {
        path = ./templates/universal;
        description = "Universal template v3.0.0 with enhanced detection - versioned for cache-busting";
      };
      rails-v3-0-0 = {
        path = ./templates/universal;
        description = "Rails template v3.0.0 with enhanced detection - versioned for cache-busting";
      };

      # 🔄 Legacy compatibility (deprecated but functional)
      ruby-fixed = {
        path = ./templates/universal;
        description = "[DEPRECATED] Use 'universal' or 'rails' instead - same functionality";
      };
      ruby-v2-2-3 = {
        path = ./templates/universal;
        description = "[DEPRECATED] Use 'universal-v3-0-0' instead - same functionality with improvements";
      };
      ruby-v2-2-9 = {
        path = ./templates/universal;
        description = "[DEPRECATED] Use 'universal-v3-0-0' instead - same functionality with improvements";
      };
      ruby-v2-2-8 = {
        path = ./templates/universal;
        description = "[DEPRECATED] Use 'universal-v3-0-0' instead - same functionality with improvements";
      };
      ruby-v2-2-7 = {
        path = ./templates/universal;
        description = "[DEPRECATED] Use 'universal-v3-0-0' instead - same functionality with improvements";
      };
      ruby-v2-2-5 = {
        path = ./templates/universal;
        description = "[DEPRECATED] Use 'universal-v3-0-0' instead - same functionality with improvements";
      };
      ruby-v2-2-6 = {
        path = ./templates/universal;
        description = "[DEPRECATED] Use 'universal-v3-0-0' instead - same functionality with improvements";
      };
    };

    # DevShells for direct access (useful for CI/CD and quick bootstrapping)
    # Usage: nix develop github:glenndavy/rails-builder#with-bundix-bootstrap \
    #          --override-input src path:.
    devShells = forAllSystems (system: let
      pkgs = mkPkgsForSystem system;
      versionDetection = import ./imports/detect-versions.nix;
      customBundix = mkBundixForSystem system;

      # Detect Ruby version from src input, with fallback for CI/when no .ruby-version exists
      rubyVersionFile = src + "/.ruby-version";
      hasRubyVersion = builtins.pathExists rubyVersionFile;
      rubyVersion =
        if hasRubyVersion
        then versionDetection.detectRubyVersion {inherit src;}
        else "3.3.0"; # Fallback version for CI and when no .ruby-version
      rubyPackage = pkgs."ruby-${rubyVersion}";
    in {
      # Bootstrap shell with bundix for generating gemset.nix
      with-bundix-bootstrap = pkgs.mkShell {
        name = "rails-builder-bootstrap";
        buildInputs =
          [
            rubyPackage
            customBundix
            pkgs.bundler
            pkgs.git
            pkgs.gnumake
            pkgs.gcc
            pkgs.pkg-config
            pkgs.openssl
            pkgs.libyaml
            pkgs.zlib
            pkgs.libffi
            pkgs.readline
            pkgs.ncurses
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            pkgs.libxml2
            pkgs.libxslt
            pkgs.postgresql
          ];

        shellHook = ''
          echo "Rails Builder Bootstrap Shell (${system})"
          echo "Ruby: $(ruby --version)"
          echo "Bundix: $(bundix --version 2>/dev/null || echo 'available')"
          echo ""
          echo "This shell is for bootstrapping new projects."
          echo "For full development, initialize a project with:"
          echo "  nix flake init -t github:glenndavy/rails-builder#universal"
          echo "  nix develop .#with-bundler"
        '';
      };

      # Alias for convenience
      default = pkgs.mkShell {
        name = "rails-builder-default";
        buildInputs = [
          rubyPackage
          pkgs.bundler
          pkgs.git
        ];
        shellHook = ''
          echo "Rails Builder Default Shell (${system})"
          echo "Ruby: $(ruby --version)"
          echo ""
          echo "For full development, initialize a project with:"
          echo "  nix flake init -t github:glenndavy/rails-builder#universal"
        '';
      };
    });

    # NixOS modules for systemd service deployment
    nixosModules = {
      # Core module (framework agnostic)
      ruby-app = import ./nixos-modules/rails-app.nix;

      # Framework-specific aliases for discoverability
      rails-app = self.nixosModules.ruby-app;
      hanami-app = self.nixosModules.ruby-app;
      sinatra-app = self.nixosModules.ruby-app;
      rack-app = self.nixosModules.ruby-app;

      # Default points to generic name
      default = self.nixosModules.ruby-app;
    };
  };
}
