{pkgs ? import <nixpkgs> {system = "x86_64-linux";}}: let
  builderVersion = "13";
in
  pkgs.dockerTools.buildImage {
    name = "opscare-builder";
    tag = "latest";
    fromImage = "docker.io/library/ubuntu:jammy";
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
      Cmd = ["/bin/bash"];
      Env = [
        "PATH=/home/app-builder/.nix-profile/bin:/bin:/sbin"
        "NIX_PATH=nixpkgs=${pkgs.path}"
        "NIXPKGS_ALLOW_INSECURE=1"
        "BUILDER_VERSION=${builderVersion}"
      ];
      WorkingDir = "/source";
      User = "app-builder";
    };
    extraCommands = ''
      # Debug
      echo "**${builderVersion}****************** RUNNING EXTRA COMMANDS ************************"
      # Create /source directory
      mkdir -p source
      chown 1000:1000 source
      chmod 775 source
      # Create /tmp with world-writable permissions
      mkdir -p tmp
      chmod 1777 tmp
      # Create /home/app-builder/.cache/nix
      mkdir -p home/app-builder/.cache/nix
      chown 1000:1000 home/app-builder/.cache/nix
      chmod 775 home/app-builder/.cache/nix
      # Create /nix/var/nix/profiles/per-user/app-builder
      mkdir -p nix/var/nix/profiles/per-user/app-builder
      chown 1000:1000 nix/var/nix/profiles/per-user/app-builder
      chmod 775 nix/var/nix/profiles/per-user/app-builder
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
    runAsRoot = ''
      #!/bin/bash
      echo "DEBUG: Running runAsRoot for version ${builderVersion}" >&2
      # Install dependencies for Nix and gem compilation
      apt-get update
      apt-get install -y curl git build-essential
      # Create app-builder user
      groupadd -g 1000 app-builder
      useradd -u 1000 -g app-builder -m -d /home/app-builder -s /bin/bash app-builder
      # Install Nix in single-user mode as app-builder
      su - app-builder -c "curl -L https://nixos.org/nix/install | sh -s -- --no-daemon"
      # Set ownership and permissions
      chown -R 1000:1000 /home/app-builder /home/app-builder/.cache/nix /nix
      chmod -R 775 /home/app-builder /home/app-builder/.cache/nix /nix
      chmod -R o+r /etc/ssl/certs
    '';
  }
