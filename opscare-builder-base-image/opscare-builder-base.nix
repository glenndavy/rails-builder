{pkgs ? import <nixpkgs> {system = "x86_64-linux";}}: let
  builderVersion = "7";
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
      # Create /home/app-builder
      mkdir -p home/app-builder
      chmod 755 home/app-builder
      # Create /etc/nix/nix.conf
      mkdir -p etc/nix
      cat <<NIX_CONF > etc/nix/nix.conf
      download-buffer-size = 83886080
      experimental-features = nix-command flakes
      accept-flake-config = true
      allow-unsafe-native-code-during-evaluation = true
      NIX_CONF
      # Create /etc/default/useradd
      mkdir -p etc/default
      echo "CREATE_MAIL_SPOOL=no" > etc/default/useradd
      # Create /etc/passwd and /etc/group
      mkdir -p etc
      echo "root:x:0:0::/root:/bin/bash" > etc/passwd
      echo "app-builder:x:1000:1000::/home/app-builder:/bin/bash" >> etc/passwd
      echo "nixbld:x:30000:" > etc/group
      echo "app-builder:x:1000:nixbld" >> etc/group
      chmod 644 etc/passwd etc/group
    '';
  }
