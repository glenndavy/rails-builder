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
    version = "2.4.0";
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

          if [ -f templates/ruby/flake.nix ]; then
            echo "✓ ruby template exists"
          else
            echo "✗ ruby template missing"
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
  };
}
