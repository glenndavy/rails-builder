{
  description = "Rails app template";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
    src = ./.;
  };
  outputs = {
    self,
    nixpkgs,
    nixpkgs-ruby,
    flake,
    src,
  }: let
    system = "x86_64-linux";
    overlays = [nixpkgs-ruby.overlays.default];
    pkgs = import nixpkgs {
      inherit system overlays;
      config.permittedInsecurePackages = ["openssl-1.1.1w"];
    };
    version = "1.0.0";
    gccVersion = "latest";
    opensslVersion = "3";
    #detect ruby version
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
        else throw "Error: No .ruby-version found in RAILS_ROOT";
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

    # end detect ruby version

    #detect bundler version
    detectBundlerVersion = {src}: let
      gemfileLock = src + "/Gemfile.lock";
      gemfile = src + "/Gemfile";
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
      fromGemfile =
        if builtins.pathExists gemfile
        then let
          content = builtins.readFile gemfile;
          match = builtins.match ".*gem ['\"]bundler['\"], ['\"](~> )?([0-9.]+)['\"].*" content;
        in
          if match != null && parseVersion (builtins.elemAt match 1) != null
          then builtins.elemAt match 1
          else fromGemfileLock
        else fromGemfileLock;
    in
      fromGemfile;

    #end detect bundler version
    rubyVersion = detectRubyVersion {src = ./.;};
    bundlerVersion = detectBundlerVersion {src = ./.;};
    rubyPackage = pkgs."ruby-${rubyVersion}";
    rubyVersionSplit = builtins.splitVersion rubyVersion;
    rubyMajorMinor = "${builtins.elemAt rubyVersionSplit 0}.${builtins.elemAt rubyVersionSplit 1}";

    #usrBin derivation
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
        echo "DEBUG: usrBinDerviation install phase" >&2
        echo "DEBUG: Creating usr/bin/env symlink" >&2
        mkdir -p $out/usr/bin
        ln -sf ${pkgs.coreutils}/bin/env $out/usr/bin/env
        echo "DEBUG: usrBinDerivation completed" >&2
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
    universalBuildInputs = [
      rubyPackage
      usrBinDerivation
      tzinfo
      opensslPackage
      pkgs.libpqxx
      pkgs.sqlite
      pkgs.libxml2
      pkgs.libxslt
      pkgs.zlib
      pkgs.libyaml
      pkgs.postgresql
      pkgs.zlib
      pkgs.libyaml
      pkgs.curl
    ];

    manage-postgres-script = pkgs.writeShellScriptBin "manage-postgres" (import ./imports/manage-postgres-script.nix {inherit pkgs;});
    manage-redis-script = pkgs.writeShellScriptBin "manage-redis" (import ./imports/manage-redis-script.nix {inherit pkgs;});
    #make-rails-app = pkgs.writeShellScriptBin "make-rails-app" (import ./imports/make-rails-app.nix {inherit pkgs;});

    builderExtraInputs = [
      gccPackage
      pkgs.pkg-config
      pkgs.rsync
    ];

    defaultShellHook = ''
      echo "DEBUG: Shell hook for shell " >&2
      export PS1="shell:>"
      export PKG_CONFIG_PATH="${pkgs.curl.dev}/lib/pkgconfig:${pkgs.postgresql}/lib/pkgconfig"
      export LD_LIBRARY_PATH="${pkgs.curl}/lib:${pkgs.postgresql}/lib:${opensslPackage}/lib"
      unset RUBYLIB GEM_PATH
      echo "DEBUG: shell hook done" >&2
    '';

    builderShellHook =
      defaultShellHook
      ++ ''
        echo "DEBUG: builder Shell hook" >&
        export PS1="$(pwd) railsBuild shell >"
        export NIXPKGS_ALLOW_INSECURE=1
        export RAILS_ROOT=$(pwd)
        export source=$RAILS_ROOT
        export RUBYLIB=${rubyPackage}/lib/ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/site_ruby/${rubyMajorMinor}.0
        export RUBYOPT=-I${rubyPackage}/lib/ruby/${rubyMajorMinor}.0
        export PATH=${rubyPackage}/bin:$GEM_HOME/bin:$HOME/.nix-profile/bin:$PATH
        # pausing on this, till we know we can't use the bundler package
        #${rubyPackage}/bin/gem install bundler:${bundlerVersion} --no-document
      '';

    appSrc = pkgs.stdenv.mkDerivation {
      name = "rails-app";
      inherit src;
      nativeBuildInputs = [pkgs.rsync pkgs.coreutils pkgs.bash];
      buildInputs = universalBuildInputs;
      installPhase = ''
        echo "DEBUG: rails-app install phase start" >&2
        mkdir -p $out/app
        rsync -a --delete --include '.*' --exclude 'flake.nix' --exclude 'flake.lock' --exclude 'prepare-build.sh' . $out/app
        echo "DEBUG: Filesystem setup completed" >&2
        echo "DEBUG: rails-app install phase done" >&2
      '';
    };
  in {
    packages.classic.${system} = {
      ruby = rubyPackage;
      railsPackge = "placeholder";
      dockerImage = "placeholder";
      #railsAppModule="placeholder"
    };
    scripts.classic.${system} = {
      minimalShell = {};
      devShell = {};
      makeShell = {};
    };
  };
}
