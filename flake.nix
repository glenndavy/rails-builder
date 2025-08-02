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
          pkgs.sqlite
          pkgs.libxml2
          pkgs.libxslt
          pkgs.libyaml
        ];
        shellHook = ''
          export PKG_CONFIG_PATH="${pkgs.curl.dev}/lib/pkgconfig:${pkgs.postgresql}/lib/pkgconfig"
          export LD_LIBRARY_PATH="${pkgs.curl}/lib:${pkgs.postgresql}/lib:${opensslPackage}/lib"
          export TZDIR="$HOME/zoneinfo"
          mkdir -p "$HOME/zoneinfo"
          ln -sf "${pkgs.tzdata}/share/zoneinfo" "$HOME/zoneinfo"
        '';
      };
    in {
      inherit shell app;
      # In rails-builder flake.nix, inside mkRailsBuild
      dockerImage = let
        shellEnv = shell;
      commitSha = if src ? rev then builtins.substring 0 8 src.rev else "latest";
      in pkgs.dockerTools.buildLayeredImage {
        name = "rails-app";
        tag = commitSha;
        contents = [
          app
            pkgs.goreman
            rubyPackage
            pkgs.bundler
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
            pkgs.coreutils # For /bin/env and other utilities
            (pkgs.stdenv.mkDerivation {
             name = "rails-app-gems";
             buildInputs = shell.buildInputs;
             src = app;
             installPhase = ''
             mkdir -p $out/app/vendor
             if [ -d "${app}/app/vendor/bundle" ]; then
             echo "DEBUG: Copying vendor/bundle from ${app}/app/vendor/bundle" >&2
             cp -r ${app}/app/vendor/bundle $out/app/vendor/bundle
             chmod -R u+w $out/app/vendor/bundle
             echo "DEBUG: Contents of $out/app/vendor/bundle:" >&2
             ls -lR $out/app/vendor/bundle >&2
             else
             echo "ERROR: No vendor/bundle found in ${app}/app" >&2
             exit 1
             fi
             '';
             })
        ];
        config = {
          Cmd = [ "${pkgs.bash}/bin/bash" "-c" "echo 'DEBUG: Contents of /app:' && ls -l /app && echo 'DEBUG: Contents of /app/vendor/bundle:' && ls -lR /app/vendor/bundle && echo 'DEBUG: Checking bundle executable:' && [ -f /app/vendor/bundle/bin/bundle ] && chmod +x /app/vendor/bundle/bin/bundle && ls -l /app/vendor/bundle/bin/bundle && echo 'DEBUG: Checking /usr/bin/env:' && ls -l /usr/bin/env && echo 'DEBUG: Bundle config:' && bundle config && echo 'DEBUG: Installed gems:' && bundle list && ${pkgs.goreman}/bin/goreman start web" ];
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
          extraCommands = ''
            echo "DEBUG: Starting extraCommands" >&2
            mkdir -p usr/bin
            #ln -s ${pkgs.coreutils}/bin/env usr/bin/env
            #echo "DEBUG: Created usr/bin/env symlink" >&2
            #ls -l usr/bin/env >&2
            #mkdir -p root/zoneinfo
            #ln -sf ${pkgs.tzdata}/share/zoneinfo root/zoneinfo
            #mkdir -p app/.nix-gems
            #ln -sf ${rubyPackage}/bin/* usr/local/bin/
            #                            echo "DEBUG: Contents of usr/local/bin:" >&2
            #                            ls -l usr/local/bin >&2
            #                            if [ -f app/vendor/bundle/bin/bundle ]; then
            #                            chmod +x app/vendor/bundle/bin/bundle
            #                            echo "DEBUG: Made app/vendor/bundle/bin/bundle executable" >&2
            #                            ls -l app/vendor/bundle/bin/bundle >&2
            #                            else
            #                            echo "ERROR: app/vendor/bundle/bin/bundle not found" >&2
            #                            fi
            echo "DEBUG: extraCommands completed" >&2
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
