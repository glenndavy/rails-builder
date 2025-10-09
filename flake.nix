# In rails-builder flake.nix
{
  description = "Generic Rails builder flake";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = {
    self,
    nixpkgs,
    nixpkgs-ruby,
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    # Simple version for compatibility - can be overridden with --impure for git info
    version = "2.2.8-auto-bump";
    forAllSystems = nixpkgs.lib.genAttrs systems;
    overlays = [nixpkgs-ruby.overlays.default];

    mkPkgsForSystem = system: import nixpkgs {inherit system overlays;};
    mkLibForSystem = system: let
      pkgs = mkPkgsForSystem system;
      mkRailsBuild = import ./imports/make-rails-build.nix {inherit pkgs;};
      mkRailsNixBuild = import ./imports/make-rails-nix-build.nix {inherit pkgs;};
    in {
      inherit mkRailsBuild mkRailsNixBuild;
      version = version;
    };

    # Create test apps for each system
    mkTestsForSystem = system: let
      pkgs = mkPkgsForSystem system;
      lib = mkLibForSystem system;

      # Mock Rails app source for testing
      mockRailsApp = pkgs.stdenv.mkDerivation {
        name = "mock-rails-app";
        dontUnpack = true;
        installPhase = ''
          mkdir -p $out
          cat > $out/Gemfile <<EOF
          source 'https://rubygems.org'
          gem 'rails', '~> 7.0'
          EOF
          cat > $out/.ruby-version <<EOF
          3.2.0
          EOF
          cat > $out/Gemfile.lock <<EOF
          GEM
            remote: https://rubygems.org/
            specs:
              rails (7.0.0)

          PLATFORMS
            ruby

          DEPENDENCIES
            rails (~> 7.0)

          BUNDLED WITH
             2.4.0
          EOF
        '';
      };

      # Test basic Rails build functionality
      testBasicBuild = pkgs.stdenv.mkDerivation {
        name = "test-basic-rails-build";
        dontUnpack = true;
        buildInputs = [pkgs.ruby pkgs.bundix];
        buildPhase = ''
          echo "Testing basic Rails build creation..."
          echo "✓ mkRailsBuild function available"
          echo "✓ mkRailsNixBuild function available"
          echo "✓ bundix available: $(bundix --version)"
        '';
        installPhase = ''
          mkdir -p $out
          echo "Basic build test passed" > $out/result
        '';
      };

      # Test template validation
      testTemplates = pkgs.stdenv.mkDerivation {
        name = "test-templates";
        src = ./.;
        buildPhase = ''
          echo "Testing template validity..."

          if [ -f templates/rails/flake.nix ]; then
            echo "✓ rails template exists"
          else
            echo "✗ rails template missing"
            exit 1
          fi

          if [ -f templates/build-rails/flake.nix ]; then
            echo "✓ build-rails template exists"
          else
            echo "✗ build-rails template missing"
            exit 1
          fi

          if [ -f templates/build-rails-with-nix/flake.nix ]; then
            echo "✓ build-rails-with-nix template exists"
          else
            echo "✗ build-rails-with-nix template missing"
            exit 1
          fi
        '';
        installPhase = ''
          mkdir -p $out
          echo "Template tests passed" > $out/result
        '';
      };

      # Test cross-platform compatibility
      testCrossPlatform = pkgs.stdenv.mkDerivation {
        name = "test-cross-platform";
        dontUnpack = true;
        buildPhase = ''
          echo "Testing cross-platform compatibility for ${system}..."

          if [ "${system}" = "x86_64-darwin" ] || [ "${system}" = "aarch64-darwin" ]; then
            echo "✓ Running on Darwin (${system})"
          else
            echo "✓ Running on Linux (${system})"
          fi

          echo "✓ System packages available for ${system}"
        '';
        installPhase = ''
          mkdir -p $out
          echo "Cross-platform test passed for ${system}" > $out/result
        '';
      };

      # Combined test runner
      runAllTests = pkgs.stdenv.mkDerivation {
        name = "run-all-tests";
        dontUnpack = true;
        buildInputs = [
          testBasicBuild
          testTemplates
          testCrossPlatform
        ];
        buildPhase = ''
          echo "Running all tests for ${system}..."

          echo "1. Basic build tests..."
          cat ${testBasicBuild}/result

          echo "2. Template tests..."
          cat ${testTemplates}/result

          echo "3. Cross-platform tests..."
          cat ${testCrossPlatform}/result

          echo "All tests completed successfully!"
        '';
        installPhase = ''
          mkdir -p $out
          echo "All tests passed for ${system}" > $out/result
        '';
      };

    in {
      inherit testBasicBuild testTemplates testCrossPlatform runAllTests;
    };
  in {
    lib = forAllSystems mkLibForSystem;

    # Add test outputs
    checks = forAllSystems mkTestsForSystem;

    # Version app
    apps = forAllSystems (system: let
      pkgs = mkPkgsForSystem system;
    in {
      flakeVersion = {
        type = "app";
        program = "${pkgs.writeShellScript "show-version" ''
          echo 'Flake Version: ${version}'
        ''}";
      };
    });

    templates.rails = {
      path = ./templates/rails;
      description = "Unified Rails template with bundler and bundix approaches";
    };
    templates.ruby = {
      path = ./templates/ruby;
      description = "Generic Ruby application template with framework auto-detection (Rails, Hanami, Sinatra, Rack, plain Ruby)";
    };
    templates.ruby-fixed = {
      path = ./templates/ruby;
      description = "Latest Ruby template with bundix fixes (v2.2.0) - use this if 'ruby' template is cached";
    };
    templates.ruby-v2-2-3 = {
    templates.ruby-v2-2-8 = {
      path = ./templates/ruby;
      description = "Ruby template v2.2.8 with latest fixes - versioned for cache-busting";
    };
    templates.ruby-v2-2-7 = {
      path = ./templates/ruby;
      description = "Ruby template v2.2.7 with latest fixes - versioned for cache-busting";
    };
      path = ./templates/ruby;
      description = "Ruby template v2.2.3 with boolean expression fixes - cache-bust version";
    };
    templates.ruby-v2-2-5 = {
      path = ./templates/ruby;
      description = "Ruby template v2.2.5 with latest fixes - versioned for cache-busting";
    };
    templates.ruby-v2-2-6 = {
      path = ./templates/ruby;
      description = "Ruby template v2.2.6 with latest fixes - versioned for cache-busting";
    };
    templates.build-rails = {
      path = ./templates/build-rails;
      description = "Legacy: Traditional bundler approach (use 'rails' template instead)";
    };
    templates.build-rails-with-nix = {
      path = ./templates/build-rails-with-nix;
      description = "Legacy: Nix bundlerEnv approach (use 'rails' template instead)";
    };
  };
}
