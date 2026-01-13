{pkgs, ...}: {
  rubyVersion,
  gccVersion ? "latest",
  opensslVersion ? "3_2",
  src ? ./.,
  buildRailsApp,
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
      mkdir -p $out/usr/bin
      ln -sf ${pkgs.coreutils}/bin/env $out/usr/bin/env
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
    tzinfo
    pkgs.libvips
    pkgs.pkg-config
  ];

  app = pkgs.stdenv.mkDerivation {
    name = "rails-app";
    inherit src;
    nativeBuildInputs = [pkgs.rsync pkgs.coreutils pkgs.bash buildRailsApp];
    buildInputs = universalBuildInputs;
    buildPhase = ''
      export HOME=$PWD
      export source=$PWD
    '';

    installPhase = ''
      mkdir -p $out/app
      rsync -a --delete --include '.*' --exclude 'flake.nix' --exclude 'flake.lock' --exclude 'prepare-build.sh' . $out/app
    '';
  };

  shell = pkgs.mkShell {
    buildInputs =
      universalBuildInputs
      ++ [
        gccPackage
        pkgs.pkg-config
        pkgs.gosu
        pkgs.rsync
        pkgs.nodejs
      ];

    shellHook = ''
      export PS1="shell:>"
      export PKG_CONFIG_PATH="${pkgs.curl.dev}/lib/pkgconfig:${pkgs.postgresql}/lib/pkgconfig"
      export LD_LIBRARY_PATH="${pkgs.curl}/lib:${pkgs.postgresql}/lib:${opensslPackage}/lib"
    '';
  };
in {
  inherit shell app;
  dockerImage = let
    commitSha =
      if src ? rev
      then builtins.substring 0 8 src.rev
      else "latest";
  in
    pkgs.dockerTools.buildLayeredImage {
      name = "rails-app-image";
      contents =
        universalBuildInputs
        ++ [
          app
          usrBinDerivation
          pkgs.goreman
          rubyPackage
          pkgs.curl
          opensslPackage
          pkgs.rsync
          pkgs.zlib
          pkgs.nodejs
          pkgs.bash
          pkgs.coreutils
        ]
        ++ (
          if pkgs.stdenv.isLinux
          then [pkgs.gosu]
          else []
        );
      config = {
        Cmd = [
          "${pkgs.bash}/bin/bash"
          "-c"
          "${
            if pkgs.stdenv.isLinux
            then "${pkgs.gosu}/bin/gosu app_user "
            else ""
          }${pkgs.goreman}/bin/goreman start web"
        ];
        Env = [
          "BUNDLE_PATH=/app/vendor/bundle"
          "BUNDLE_GEMFILE=/app/Gemfile"
          "RAILS_ENV=production"
          "RUBYLIB=${rubyPackage}/lib/ruby/${rubyMajorMinor}.0:${rubyPackage}/lib/ruby/site_ruby/${rubyMajorMinor}.0"
          "RUBYOPT=-I${rubyPackage}/lib/ruby/${rubyMajorMinor}.0"
          "PATH=/app/vendor/bundle/bin:${rubyPackage}/bin:/usr/local/bin:/usr/bin:/bin"
          "TZDIR=/usr/share/zoneinfo"
        ];
        WorkingDir = "/app";
        enableFakechroot = !pkgs.stdenv.isDarwin;
        fakeRootCommands = ''
          mkdir -p /etc
          cat > /etc/passwd <<-EOF
          root:x:0:0::/root:/bin/bash
          app_user:x:1000:1000:App User:/app:/bin/bash
          EOF
          cat > /etc/group <<-EOF
          root:x:0:
          app_user:x:1000:
          EOF
          cat > /etc/shadow <<-EOF
          root:*:18000:0:99999:7:::
          app_user:*:18000:0:99999:7:::
          EOF
          chown -R 1000:1000 /app
          chmod -R u+w /app
        '';
      };
    };
}
