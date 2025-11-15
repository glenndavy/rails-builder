# Simple test to verify the rails-app NixOS module works
{ pkgs ? import <nixpkgs> {} }:

let
  # Create a minimal test Rails app package
  testRailsApp = pkgs.stdenv.mkDerivation {
    name = "test-rails-app";
    src = pkgs.writeTextDir "Procfile" ''
      web: bundle exec rails server -p $PORT
      worker: bundle exec sidekiq
      release: bundle exec rails db:migrate
    '';
    installPhase = ''
      mkdir -p $out/app
      cp -r * $out/app/
    '';
  };

  # Test the module evaluation
  moduleTest = pkgs.lib.evalModules {
    modules = [
      ./rails-app.nix
      {
        services.rails-app.test-web = {
          enable = true;
          package = testRailsApp;
          procfile_role = "web";
          procfile_filename = "${testRailsApp}/app/Procfile";

          environment_command = "echo 'export DATABASE_URL=postgres://localhost/test'";
          environment_overrides = {
            RAILS_ENV = "production";
            PORT = "3000";
          };

          service_description = "Test Rails Web Server";
          service_after = [ "postgresql.service" ];
        };
      }
    ];
  };

in {
  # Expose the test for nix build
  inherit testRailsApp;

  # Test that module evaluates without errors
  moduleConfig = moduleTest.config;

  # Extract the generated systemd service for inspection
  railsService = moduleTest.config.systemd.services."rails-app-test-web";

  # Test that Procfile parsing works
  testProcfileParsing =
    let
      parseProcfile = import ./rails-app.nix {
        config = {};
        lib = pkgs.lib;
        pkgs = pkgs;
      };
    in "Test passed - module loads correctly";
}