{
  description = "Dentalportal Rails app";
  version = "2.0.0"; # Frontend version

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rails-builder.url = "github:your-org/rails-builder"; # Adjust to your repo
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
  };

  outputs = {
    self,
    nixpkgs,
    rails-builder,
    flake-compat,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};

    # Read .ruby-version or error out
    rubyVersionFile = ./.ruby-version;
    rubyVersion =
      if builtins.pathExists rubyVersionFile
      then builtins.readFile rubyVersionFile
      else throw "Error: No .ruby-version found in RAILS_ROOT. Please specify a Ruby version.";

    # Read bundler version from Gemfile.lock or default to latest
    gemfileLock = ./Gemfile.lock;
    bundlerVersion =
      if builtins.pathExists gemfileLock
      then let
        lockContent = builtins.readFile gemfileLock;
        match = builtins.match ".*BUNDLED WITH\n   ([0-9.]+).*" lockContent;
      in
        if match != null
        then builtins.head match
        else "latest"
      else "latest";

    # App-specific customizations
    buildConfig = {
      inherit rubyVersion;
      bundlerVersion = bundlerVersion;
      gccVersion = "latest";
      opensslVersion = "3_2";
    };

    # Call backend builder
    railsBuild = rails-builder.lib.mkRailsBuild buildConfig;
  in {
    devShells.${system}.buildShell = railsBuild.shell.overrideAttrs (old: {
      shellHook =
        old.shellHook
        + ''
          export BUNDLE_PATH=/builder/.bundle
          export BUNDLE_GEMFILE=/builder/Gemfile
        '';
    });
    packages.${system}.buildApp = railsBuild.app;
    packages.${system}.dockerImage = railsBuild.dockerImage;
    packages.${system}.flakeVersion = pkgs.writeText "flake-version" ''
      Frontend Flake Version: ${self.version}
      Backend Flake Version: ${rails-builder.version}
    '';
    apps.${system}.flakeVersion = {
      type = "app";
      program = "${self.packages.${system}.flakeVersion}";
    };
  };
}
