{
  description = "Generic Rails builder flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-ruby }: let
    system = "x86_64-linux";
    version = "2.0.27"; # Backend version
    overlays = [nixpkgs-ruby.overlays.default];
    pkgs = import nixpkgs { inherit system overlays; };

    # Function to create build environment
  mkRailsBuild = {
    rubyVersion,
    gccVersion ? "latest",
    opensslVersion ? "3_2",
    src ? ./.,
  }: let
    rubyPackage = pkgs."ruby-${rubyVersion}";
    gccPackage =
      if gccVersion == "latest"
      then pkgs.gcc
      else pkgs."gcc${gccVersion}";
    opensslPackage =
      if opensslVersion == "3_2"
      then pkgs.openssl_3
      else pkgs."openssl_${opensslVersion}";
    app = pkgs.stdenv.mkDerivation {
      name = "rails-app";
      inherit src;
      buildInputs = [pkgs.rsync];
      installPhase = ''
        mkdir -p $out/app
        cp -r . $out/app
        if [ -d "$src/vendor/bundle" ]; then
          rsync -a --delete "$src/vendor/bundle/" "$out/app/vendor/bundle/"
        fi
        if [ -d "$src/public/packs" ]; then
          rsync -a --delete "$src/public/packs/" "$out/app/public/packs/"
        fi
      '';
    };
  in {
    shell = pkgs.mkShell {
      buildInputs = [
        rubyPackage
        gccPackage
        opensslPackage
        pkgs.curl
        pkgs.tzdata
        pkgs.pkg-config
        pkgs.zlib
        pkgs.libyaml
        pkgs.gosu
        pkgs.postgresql
        pkgs.rsync
        pkgs.nodejs
      ];
      shellHook = ''
        export PKG_CONFIG_PATH="${pkgs.curl.dev}/lib/pkgconfig:${pkgs.postgresql}/lib/pkgconfig"
        export LD_LIBRARY_PATH="${pkgs.curl}/lib:${pkgs.postgresql}/lib:${opensslPackage}/lib"
        export TZDIR="$HOME/zoneinfo"
        mkdir -p "$HOME/zoneinfo"
        ln -sf "${pkgs.tzdata}/share/zoneinfo" "$HOME/zoneinfo"
      '';
    };
    inherit app;
    # In rails-builder flake.nix
    # In rails-builder flake.nix
    dockerImage = let
    # Use buildShell to inherit its environment
       shellEnv = railsBuild.shell; # Reference the buildShell from the app template
       # Extract the first 8 characters of the commit SHA
       commitSha = if src ? rev then builtins.substring 0 8 src.rev else "latest";
    in pkgs.dockerTools.buildLayeredImage {
      name = "rails-app";
      tag = commitSha; # Use the commit SHA as the tag
      contents = [
          app
          pkgs.goreman
          rubyPackage
          pkgs.curl
          opensslPackage
          pkgs.postgresql
          pkgs.rsync
          pkgs.tzdata
          pkgs.zlib
          pkgs.gosu
          pkgs.nodejs
          pkgs.libyaml
          pkgs.bash
          pkgs.busybox
          (pkgs.stdenv.mkDerivation {
             name = "rails-app-gems";
             buildInputs = shellEnv.buildInputs;
             src = app;
             installPhase = ''
             mkdir -p $out/app/vendor
             if [ -d "${app}/app/vendor/bundle" ]; then
             cp -r ${app}/app/vendor/bundle $out/app/vendor/bundle
             fi
             '';
             })
        ];
      config = {
        Cmd = [ "${pkgs.bash}/bin/bash" "-c" "${pkgs.goreman}/bin/goreman start web" ];
        Env = [
          "BUNDLE_PATH=/app/vendor/bundle"
            "BUNDLE_GEMFILE=/app/Gemfile"
            "RAILS_ENV=production"
            "GEM_HOME=/app/.nix-gems"
            "GEM_PATH=/app/.nix-gems:${rubyPackage}/lib/ruby/gems/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/${rubyMajorMinor}.0"
            "RUBYLIB=${rubyPackage}/lib/ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/site_ruby/${rubyMajorMinor}.0"
            "RUBYOPT=-I${rubyPackage}/lib/ruby/${rubyMajorMinor}.0"
            "PATH=/app/vendor/bundle/bin:${rubyPackage}/bin:/root/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin"
            "TZDIR=/root/zoneinfo"
        ];
        ExposedPorts = { "3000/tcp" = {}; };
        WorkingDir = "/app";
        ExtraCommands = ''
          mkdir -p /root/zoneinfo
          ln -sf ${pkgs.tzdata}/share/zoneinfo /root/zoneinfo
          mkdir -p /app/.nix-gems
          ln -sf ${rubyPackage}/bin/* /usr/local/bin/
       '';
       };
    };
  };
  in {
    lib = {
      inherit mkRailsBuild;
      version = version;
    };
    templates.new-app = {
      path = ./templates/new-app;
      description = "A template for a Rails application";
    };
  };
}
