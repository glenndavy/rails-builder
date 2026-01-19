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
      workingDir = "${appPackage}/app";

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

      # Change to application directory
      cd ${workingDir}

      # Set up PATH to include Ruby, gems, and bundler
      # This ensures 'bundle', 'rails', and other gem executables are available
      export PATH="${appPackage}/app/bin:${workingDir}/bin:$PATH"

      # Execute environment setup command if specified
      ${optionalString (instanceCfg.environment_command != null) ''
        echo "Setting up environment variables..."
        eval "$(${instanceCfg.environment_command})"
      ''}

      # Apply environment overrides
      ${envOverrides}

      # Set up Rails-specific environment
      export RAILS_ROOT=${workingDir}
      export BUNDLE_GEMFILE=${workingDir}/Gemfile

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

        # Pre-start script to set up mutable directories
        preStart = ''
          # Create mutable directories
          ${concatStringsSep "\n" (mapAttrsToList (dirName: dirPath: ''
            mkdir -p ${dirPath}
            chown ${instanceCfg.user}:${instanceCfg.group} ${dirPath}
          '') instanceCfg.mutable_dirs)}

          # Create symlinks in application directory
          APP_DIR=${instanceCfg.package}/app
          ${concatStringsSep "\n" (mapAttrsToList (dirName: dirPath: ''
            if [ ! -L "$APP_DIR/${dirName}" ]; then
              ln -sf ${dirPath} $APP_DIR/${dirName}
            fi
          '') instanceCfg.mutable_dirs)}
        '';

        serviceConfig =
          let
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
          WorkingDirectory = "${instanceCfg.package}/app";
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
          ReadWritePaths = builtins.attrValues instanceCfg.mutable_dirs;
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