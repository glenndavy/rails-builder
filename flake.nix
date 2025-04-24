{
  description = "Bank Statements Rails app";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rails-builder = {
      url = "path:../rails-builder/vendored"; # Or github:myname/rails-builder/vendored
    };
  };

  outputs = { self, nixpkgs, rails-builder }: let
    forAllSystems = f: nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ] (system: f system);
  in {
    packages = forAllSystems (system: {
      railsApp = rails-builder.lib.buildRailsApp {
        inherit system;
        rubyVersion = "3_2_6";
        src = ./.;
        gems = [ "rails" "puma" "devise" "sidekiq" "pg" ];
        railsEnv = "production";
        extraEnv = {
          RAILS_SERVE_STATIC_FILES = "true";
        };
        buildCommands = [ "bundle exec rails assets:precompile" ];
        copyFiles = [
          "Gemfile"
          "Gemfile.lock"
          "vendor/cache"
          "app"
          "config"
          "public"
          "lib"
          "bin"
          "Rakefile"
          "db"
        ];
      };
      dockerImage = rails-builder.lib.dockerImage {
        inherit system;
        railsApp = self.packages.${system}.railsApp;
        dockerCmd = [ "/app/vendor/bundle/ruby/3.2.0/bin/bundle" "exec" "puma" "-C" "/app/config/puma.rb" ];
        extraEnv = {
          RAILS_SERVE_STATIC_FILES = "true";
        };
      };
    });

    devShells = forAllSystems (system: {
      default = rails-builder.devShells.${system}.default;
    });
  };
}
