{pkgs ? import <nixpkgs> {system = "x86_64-linux";}}: let
  builderVersion = "10";
in
  pkgs.dockerTools.buildLayeredImage {
    name = "opscare-builder";
    tag = "latest";
    contents = with pkgs; [
      nixVersions.nix_2_29 # Nix 2.29
      bash
      coreutils
      curl
      rsync
      gosu
      postgresql
      redis
      git
      shadow # For useradd, groupadd, usermod
      glibc # For shared libraries
      cacert # For SSL certificates
      stdenv # For standard environment
    ];
    config = {
      Cmd = ["${pkgs.bash}/bin/bash"];
      Env = [
        "PATH=/bin:/sbin"
        "NIX_PATH=nixpkgs=${pkgs.path}"
        "NIXPKGS_ALLOW_INSECURE=1"
        "BUILDER_VERSION=${builderVersion}"
      ];
      WorkingDir = "/source";
    };
    enableFakechroot = true;
    fakeRootCommands = ''
      echo "**${builderVersion}****************** RUNNING fakeRoot COMMANDS ************************"
      # Create /etc/default/useradd
      mkdir -p etc/default
      echo "CREATE_MAIL_SPOOL=no" > etc/default/useradd
      # Use shadowSetup for user and group management
      ${pkgs.dockerTools.shadowSetup}
      groupadd -g 30000 nixbld
      useradd -u 1000 -g nixbld -m -d /home/app-builder -s /bin/bash app-builder
      # Create /home/app-builder/.cache/nix
      mkdir -p home/app-builder/.cache/nix
      chown -R app-builder:nixbld home/app-builder home/app-builder #/.cache/nix
      chmod -R 775 home/app-builder home/app-builder #/.cache/nix
      # Ensure /etc/ssl/certs is readable
      chmod -R o+r etc/ssl/certs
      chmod -R g+r etc/ssl/certs
    '';
    extraCommands = ''
      # Debug
      echo "**${builderVersion}****************** RUNNING EXTRA COMMANDS ************************"
      # Create /source directory
      mkdir -p source
      # Create /tmp with world-writable permissions
      mkdir -p tmp
      chmod 1777 tmp
      # Create /root directory
      mkdir -p root
      chmod 755 root
      # Create /etc/nix/nix.conf
      mkdir -p etc/nix
      cat <<NIX_CONF > etc/nix/nix.conf
      download-buffer-size = 83886080
      experimental-features = nix-command flakes
      accept-flake-config = true
      allow-unsafe-native-code-during-evaluation = true
      trusted-users = app-builder
      allowed-users = app-builder
      NIX_CONF
    '';
  }
