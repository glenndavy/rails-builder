{
  description = "Generic Rails builder flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-ruby }: let
    system = "x86_64-linux";
    version = "2.0.45"; # Backend version
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
		 usrBinDerivation = pkgs.stdenv.mkDerivation {
			 name = "usr-bin-env";
			 buildInputs = [pkgs.coreutils];
			 dontUnpack = true;
			 installPhase = ''
				 echo "DEBUG: Creating usr/bin/env symlink" >&2
				 mkdir -p $out/usr/bin
				 ln -sf ${pkgs.coreutils}/bin/env $out/usr/bin/env
				 echo "DEBUG: Contents of $out/usr/bin:" >&2
				 ls -l $out/usr/bin >&2
				 echo "DEBUG: usrBinDerivation completed" >&2
			 '';
		 };
		 app = pkgs.stdenv.mkDerivation {
			 name = "rails-app";
			 inherit src;
			 nativeBuildInputs = [pkgs.rsync pkgs.coreutils pkgs.bash self.packages.${system}.build-rails-app];
			 buildInputs = [
				 rubyPackage
				 pkgs.libpqxx
				 pkgs.sqlite
				 pkgs.libxml2
				 pkgs.libxslt
				 pkgs.openssl
				 pkgs.zlib
				 pkgs.libyaml
			 ];
			 buildPhase = ''
				 export HOME=$PWD
				 export source=$PWD
				 echo "DEBUG: Running build-rails-app in buildPhase" >&2
				 ${self.packages.${system}.build-rails-app}/bin/build-rails-app
				 echo "DEBUG: Contents of vendor/bundle after build-rails-app:" >&2
				 ls -lR vendor/bundle >&2
			 '';
			 installPhase = ''
				 echo "DEBUG: Source directory contents:" >&2
				 ls -lR . >&2
				 mkdir -p $out/app
				 cp -r ./* $out/app
				 if [ -d "vendor/bundle" ]; then
					 echo "DEBUG: Copying vendor/bundle to $out/app/vendor/bundle" >&2
					 rsync -a --delete "vendor/bundle/" "$out/app/vendor/bundle/"
					 chmod -R u+w $out/app/vendor/bundle
					 echo "DEBUG: Contents of $out/app/vendor/bundle:" >&2
					 ls -lR $out/app/vendor/bundle >&2
					 [ -f "$out/app/vendor/bundle/bin/bundle" ] && echo "DEBUG: bundle executable found" >&2 || echo "ERROR: bundle executable missing" >&2
					 [ -f "$out/app/vendor/bundle/bin/rails" ] && echo "DEBUG: rails executable found" >&2 || echo "ERROR: rails executable missing" >&2
				 else
					 echo "ERROR: No vendor/bundle found" >&2
					 exit 1
				 fi
				 if [ -d "public/packs" ]; then
					 rsync -a --delete "public/packs/" "$out/app/public/packs/"
					 echo "DEBUG: Contents of $out/app/public/packs:" >&2
					 ls -l $out/app/public/packs >&2
				 fi
				 echo "DEBUG: Setting up additional filesystem paths" >&2
				 mkdir -p $out/root/zoneinfo
				 ln -sf ${pkgs.tzdata}/share/zoneinfo $out/root/zoneinfo
				 mkdir -p $out/app/.nix-gems
				 mkdir -p $out/usr/local/bin
				 ln -sf ${rubyPackage}/bin/* $out/usr/local/bin/
				 echo "DEBUG: Contents of $out/usr/local/bin:" >&2
				 ls -l $out/usr/local/bin >&2
				 echo "DEBUG: Filesystem setup completed" >&2
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
		 dockerImage = let
			 commitSha = if src ? rev then builtins.substring 0 8 src.rev else "latest";
		 in pkgs.dockerTools.buildLayeredImage {
			 name = "rails-app";
			 tag = commitSha;
			 contents = [
				 app
				 usrBinDerivation
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
				 pkgs.coreutils
			 ];
			 config = {
				 Cmd = [ "${pkgs.bash}/bin/bash" "-c" "${pkgs.gosu}/bin/gosu appuser ${pkgs.goreman}/bin/goreman start web" ];
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
					 # Create non-root user and group
					 mkdir -p users/appuser
					 echo "appuser:x:1000:1000::/app:/bin/bash" > users/appuser/passwd
					 echo "appuser:x:1000:" > users/appuser/group
					 # Set ownership of /app to appuser
					 chown -R 1000:1000 app
					 chmod -R u+w app
					 echo "DEBUG: Contents of users/appuser:" >&2
					 ls -l users/appuser >&2
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
