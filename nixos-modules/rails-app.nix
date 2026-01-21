# NixOS Module for Rails Applications
# Provides systemd service configuration with secure environment handling
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.rails-app;

  # Parse Procfile to extract command for specific role
  parseProcfile = procfilePath: role:
    let
      procfileContent = builtins.readFile procfilePath;
      lines = filter (line: line != "") (splitString "\n" procfileContent);
      parseLine = line:
        let
          parts = splitString ": " line;
          procRole = head parts;
          command = concatStringsSep ": " (tail parts);
        in {
          role = procRole;
          command = command;
        };
      parsed = map parseLine lines;
      matchingRole = filter (entry: entry.role == role) parsed;
    in
      if length matchingRole > 0
      then (head matchingRole).command
      else throw "Role '${role}' not found in Procfile ${procfilePath}";

  # Create wrapper script that handles environment setup and command execution
  makeWrapperScript = name: instanceCfg:
    let
      appPackage = instanceCfg.package;
      runtimeDir = "/var/lib/rails-app-${name}/runtime";

      # Extract command from either direct specification or Procfile
      appCommand =
        if instanceCfg.command != null
        then instanceCfg.command
        else if instanceCfg.procfile_role != null && instanceCfg.procfile_filename != null
        then parseProcfile instanceCfg.procfile_filename instanceCfg.procfile_role
        else throw "Either 'command' or both 'procfile_role' and 'procfile_filename' must be specified";

      # Environment variable assignments from overrides
      envOverrides = concatStringsSep "\n" (mapAttrsToList (name: value:
        "export ${name}='${toString value}'"
      ) instanceCfg.environment_overrides);

    in pkgs.writeShellScript "rails-app-${name}-wrapper" ''
      set -euo pipefail

      # Set RAILS_ROOT for the environment script
      export RAILS_ROOT=${runtimeDir}

      # Source the build-time generated environment script
      # This sets up Ruby, gems, PATH, and all build-time known facts
      if [ -f "${appPackage}/bin/rails-env" ]; then
        echo "Loading environment from ${appPackage}/bin/rails-env"
        source "${appPackage}/bin/rails-env"
      else
        echo "Warning: No rails-env script found (old package?), using fallback"
        # Fallback for packages built with older rails-builder versions
        if [ -f "${appPackage}/nix-support/ruby-path" ]; then
          RUBY_PATH=$(cat "${appPackage}/nix-support/ruby-path")
          export PATH="$RUBY_PATH/bin:${appPackage}/app/bin:${runtimeDir}/bin:$PATH"
        fi
      fi

      # Change to runtime application directory
      cd ${runtimeDir}

      # Execute environment setup command if specified (runtime secrets, etc.)
      ${optionalString (instanceCfg.environment_command != null) ''
        echo "Setting up environment variables from command..."
        eval "$(${instanceCfg.environment_command})"
      ''}

      # Apply environment overrides (takes precedence over everything)
      ${envOverrides}

      # Execute the application command
      echo "Starting: ${appCommand}"
      exec ${appCommand}
    '';

  # Instance type definition
  instanceType = types.submodule ({ name, ... }: {
    options = {
      enable = mkEnableOption "Rails application instance";

      package = mkOption {
        type = types.package;
        description = "Rails application package to deploy";
      };

      # Command specification (either direct or Procfile-based)
      command = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Direct command to execute for this service";
        example = "bundle exec rails server -p 3000";
      };

      procfile_role = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Role name to extract from Procfile";
        example = "web";
      };

      procfile_filename = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to Procfile";
        example = "/nix/store/...-app/Procfile";
      };

      # Service lifecycle management
      stop_command = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Custom command for stopping the service";
      };

      restart_command = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Custom command for restarting the service";
      };

      # Environment management
      environment_command = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Command to populate environment variables (e.g., from AWS Parameter Store)";
        example = "aws ssm get-parameters-by-path --path /myapp/prod --query 'Parameters[*].[Name,Value]' --output text | sed 's|.*/||' | sed 's/\t/=/' | sed 's/^/export /'";
      };

      environment_overrides = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Environment variables that override those from environment_command";
        example = {
          RAILS_ENV = "production";
          PORT = "3000";
        };
      };

      # Service configuration
      service_description = mkOption {
        type = types.str;
        default = "Rails application (${name})";
        description = "Description for the systemd service";
      };

      service_after = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional systemd services this service should start after";
        example = [ "postgresql.service" "redis.service" ];
      };

      service_requires = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Services that must be running before this service starts";
        example = [ "postgresql.service" ];
      };

      service_wanted_by = mkOption {
        type = types.listOf types.str;
        default = [ "multi-user.target" ];
        description = "Systemd targets that want this service";
      };

      # User and group
      user = mkOption {
        type = types.str;
        default = "rails-app-${name}";
        description = "User to run the service as";
      };

      group = mkOption {
        type = types.str;
        default = "rails-app-${name}";
        description = "Group to run the service as";
      };

      # Mutable directories
      mutable_dirs = mkOption {
        type = types.attrsOf types.str;
        default = {
          tmp = "/var/lib/rails-app-${name}/tmp";
          log = "/var/log/rails-app-${name}";
          storage = "/var/lib/rails-app-${name}/storage";
        };
        description = "Mapping of application directories to mutable system locations";
      };

      # Additional packages to include in PATH
      path_packages = mkOption {
        type = types.listOf types.package;
        default = [];
        description = "Additional packages to include in PATH (e.g., for bundle, rails)";
        example = literalExpression "[ pkgs.ruby pkgs.bundler ]";
      };

      # Gem path for bundix/bundlerEnv builds
      gem_path = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          [DEPRECATED] This option is no longer needed as of rails-builder 3.11.0.

          Gem paths are now automatically configured by the rails-env script
          generated at build time. This option is kept for backwards compatibility
          but has no effect on packages built with rails-builder >= 3.11.0.
        '';
        example = "\${my-rails-app.packages.x86_64-linux.package-with-bundlerenv}/lib/ruby/gems/3.2.0";
      };
    };
  });

in {
  options.services.rails-app = mkOption {
    type = types.attrsOf instanceType;
    default = {};
    description = "Rails application instances";
  };

  config = mkIf (cfg != {}) {
    # Create systemd services for each enabled instance
    systemd.services = mapAttrs' (name: instanceCfg:
      nameValuePair "rails-app-${name}" {
        description = instanceCfg.service_description;
        wantedBy = instanceCfg.service_wanted_by;
        after = [ "network.target" ] ++ instanceCfg.service_after;
        requires = instanceCfg.service_requires;

        # Ensure the package is built and in the service's runtime environment
        path = [ instanceCfg.package ] ++ instanceCfg.path_packages;

        # Pre-start script to set up runtime directory and mutable directories
        preStart = let
          # Build rsync exclude list for mutable directories
          excludeArgs = concatStringsSep " " (mapAttrsToList (dirName: _: "--exclude='${dirName}'") instanceCfg.mutable_dirs);
        in ''
          RUNTIME_DIR="/var/lib/rails-app-${name}/runtime"
          SOURCE_APP="${instanceCfg.package}/app"

          # Create runtime directory
          mkdir -p "$RUNTIME_DIR"

          # Sync app from Nix store to runtime directory (if changed)
          # Exclude mutable directories since we'll replace them with symlinks
          # Use rsync to efficiently copy only changed files, preserving permissions
          # The -a flag preserves permissions, including execute bits on binstubs
          ${pkgs.rsync}/bin/rsync -a --delete ${excludeArgs} \
            "$SOURCE_APP/" "$RUNTIME_DIR/"

          # Make runtime directory writable so we can delete/create subdirectories
          # (rsync copies readonly permissions from Nix store)
          chmod u+w "$RUNTIME_DIR"

          # Create mutable directories and symlinks
          ${concatStringsSep "\n" (mapAttrsToList (dirName: dirPath: ''
            # Create external mutable directory
            mkdir -p ${dirPath}
            chown ${instanceCfg.user}:${instanceCfg.group} ${dirPath}

            # Remove any existing directory/symlink (from previous deployments)
            rm -rf "$RUNTIME_DIR/${dirName}"

            # Create symlink to external mutable directory
            ln -sfn ${dirPath} "$RUNTIME_DIR/${dirName}"
          '') instanceCfg.mutable_dirs)}

          # Set ownership of runtime directory
          chown -R ${instanceCfg.user}:${instanceCfg.group} "$RUNTIME_DIR"
        '';

        serviceConfig =
          let
            runtimeDir = "/var/lib/rails-app-${name}/runtime";
            # Build PATH from package bin dirs plus any additional path_packages
            pathDirs = [
              "${instanceCfg.package}/app/bin"
              "${pkgs.coreutils}/bin"
              "${pkgs.bash}/bin"
            ] ++ map (pkg: "${pkg}/bin") instanceCfg.path_packages
              ++ [ "/run/current-system/sw/bin" ];
            pathEnv = concatStringsSep ":" pathDirs;
          in {
          Type = "exec";
          User = instanceCfg.user;
          Group = instanceCfg.group;
          ExecStart = makeWrapperScript name instanceCfg;
          WorkingDirectory = runtimeDir;
          Restart = "always";
          RestartSec = "10s";

          # Ensure package dependencies are in PATH
          Environment = [
            "PATH=${pathEnv}"
          ];

          # Security hardening
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          # Allow writes to runtime directory and mutable directories
          ReadWritePaths = [ runtimeDir ] ++ builtins.attrValues instanceCfg.mutable_dirs;
        } // optionalAttrs (instanceCfg.stop_command != null) {
          ExecStop = instanceCfg.stop_command;
        } // optionalAttrs (instanceCfg.restart_command != null) {
          ExecReload = instanceCfg.restart_command;
        };
      }
    ) (filterAttrs (name: instanceCfg: instanceCfg.enable) cfg);

    # Create users and groups for each instance
    users.users = mapAttrs' (name: instanceCfg:
      nameValuePair instanceCfg.user {
        isSystemUser = true;
        group = instanceCfg.group;
        description = "Rails application user (${name})";
      }
    ) (filterAttrs (name: instanceCfg: instanceCfg.enable) cfg);

    users.groups = mapAttrs' (name: instanceCfg:
      nameValuePair instanceCfg.group {}
    ) (filterAttrs (name: instanceCfg: instanceCfg.enable) cfg);
  };
}