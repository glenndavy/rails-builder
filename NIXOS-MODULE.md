# Using Rails-Builder as a NixOS Module

Rails-builder provides a NixOS module for deploying Ruby applications as systemd services. This allows you to declare your Rails (or Hanami, Sinatra, Rack) application in your NixOS configuration and have it automatically built and deployed when you run `nixos-rebuild switch`.

## Features

- **Automatic systemd service creation** - Your app runs as a proper systemd service
- **Multi-role support** - Run web, worker, scheduler, and other processes from one app
- **Procfile integration** - Automatically parse commands from your Procfile
- **Environment management** - Secure environment variable handling with no secrets on disk
- **Mutable directory handling** - Automatic setup of tmp, log, and storage directories
- **Service dependencies** - Proper systemd dependency management (after, requires, wantedBy)
- **Framework agnostic** - Works with Rails, Hanami, Sinatra, Rack, or any Ruby app

## Quick Start

### 1. Prepare Your Application

Your Rails app should have a flake.nix (created with `nix flake init -t github:glenndavy/rails-builder#rails`):

```bash
cd /path/to/your/rails-app
nix flake init -t github:glenndavy/rails-builder#rails
nix run .#generate-dependencies
nix build .#package-with-bundix  # Verify it builds
```

### 2. Configure Your NixOS System

**Option A: Using /etc/nixos/flake.nix**

```nix
# /etc/nixos/flake.nix
{
  description = "NixOS system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Your Rails application
    my-rails-app = {
      url = "git+file:///home/user/my-rails-app";
      # Or from GitHub:
      # url = "github:username/my-rails-app";
    };

    # Rails-builder provides the NixOS module
    rails-builder.url = "github:glenndavy/rails-builder";
  };

  outputs = { self, nixpkgs, my-rails-app, rails-builder, ... }: {
    nixosConfigurations.myhostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix

        # Import the Rails app NixOS module
        rails-builder.nixosModules.rails-app

        # Configure your app as a service
        {
          services.rails-app.my-app-web = {
            enable = true;
            package = my-rails-app.packages.x86_64-linux.package-with-bundix;
            command = "bundle exec rails server -p 3000 -b 0.0.0.0";

            environment_overrides = {
              RAILS_ENV = "production";
              PORT = "3000";
              DATABASE_URL = "postgresql://localhost/myapp_production";
            };

            service_after = [ "postgresql.service" ];
            service_requires = [ "postgresql.service" ];
          };
        }
      ];
    };
  };
}
```

**Option B: Using configuration.nix**

```nix
# /etc/nixos/flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    my-rails-app.url = "git+file:///home/user/my-rails-app";
    rails-builder.url = "github:glenndavy/rails-builder";
  };

  outputs = { self, nixpkgs, my-rails-app, rails-builder, ... }: {
    nixosConfigurations.myhostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit my-rails-app; };
      modules = [
        ./configuration.nix
        rails-builder.nixosModules.rails-app
      ];
    };
  };
}
```

```nix
# /etc/nixos/configuration.nix
{ config, pkgs, my-rails-app, ... }:

{
  # ... your existing NixOS configuration ...

  services.rails-app.my-app-web = {
    enable = true;
    package = my-rails-app.packages.${pkgs.system}.package-with-bundix;
    command = "bundle exec rails server -p 3000 -b 0.0.0.0";

    environment_overrides = {
      RAILS_ENV = "production";
      PORT = "3000";
    };
  };
}
```

### 3. Deploy

```bash
sudo nixos-rebuild switch --flake /etc/nixos#myhostname
```

Your Rails app is now running as a systemd service!

```bash
sudo systemctl status rails-app-my-app-web.service
sudo journalctl -u rails-app-my-app-web.service -f
```

## Framework-Specific Module Names

While all module names point to the same universal implementation, you can choose the one that best describes your application:

```nix
# For Rails applications
rails-builder.nixosModules.rails-app

# For Hanami applications
rails-builder.nixosModules.hanami-app

# For Sinatra applications
rails-builder.nixosModules.sinatra-app

# For Rack applications
rails-builder.nixosModules.rack-app

# Generic (works with all)
rails-builder.nixosModules.ruby-app
```

All aliases point to the same universal module - use whichever feels most natural!

## Configuration Options

### Basic Options

```nix
services.rails-app.<name> = {
  enable = true;              # Enable this service instance
  package = <derivation>;     # Your Rails app package (required)

  # Command specification (choose ONE):
  command = "bundle exec rails server -p 3000";  # Direct command
  # OR
  procfile_role = "web";                         # Extract from Procfile
  procfile_filename = "/path/to/Procfile";       # Procfile location

  # Service user/group
  user = "rails-app-<name>";   # Default: auto-generated
  group = "rails-app-<name>";  # Default: auto-generated
};
```

### Environment Variables

```nix
services.rails-app.<name> = {
  # Static environment variables
  environment_overrides = {
    RAILS_ENV = "production";
    PORT = "3000";
    DATABASE_URL = "postgresql://localhost/myapp";
    REDIS_URL = "redis://localhost:6379/0";
  };

  # OR: Fetch from AWS Parameter Store / Secrets Manager
  environment_command = ''
    ${pkgs.awscli2}/bin/aws ssm get-parameters-by-path \
      --path /myapp/production \
      --with-decryption \
      --query 'Parameters[*].[Name,Value]' \
      --output text | \
    sed 's|/myapp/production/||' | \
    awk '{print $1"="$2}'
  '';
};
```

### Service Dependencies

```nix
services.rails-app.<name> = {
  # Start after these services
  service_after = [ "postgresql.service" "redis.service" ];

  # Require these services (fail if they fail)
  service_requires = [ "postgresql.service" ];

  # Custom service description
  service_description = "My Rails App - Web Server";
};
```

### Mutable Directories

By default, these directories are automatically created in `/var/lib/rails-app-<name>/`:

- `tmp` - Linked to `/var/lib/rails-app-<name>/tmp`
- `log` - Linked to `/var/log/rails-app-<name>/`
- `storage` - Linked to `/var/lib/rails-app-<name>/storage`

Custom mutable directories:

```nix
services.rails-app.<name> = {
  mutable_dirs = {
    tmp = "/custom/tmp/path";
    log = "/custom/log/path";
    storage = "/custom/storage/path";
    uploads = "/custom/uploads/path";
  };
};
```

## Usage Examples

### Example 1: Simple Rails Web Server

```nix
services.rails-app.blog-web = {
  enable = true;
  package = blog-app.packages.x86_64-linux.package-with-bundix;
  command = "bundle exec rails server -p 3000 -b 0.0.0.0";

  environment_overrides = {
    RAILS_ENV = "production";
    PORT = "3000";
    DATABASE_URL = "postgresql://localhost/blog_production";
  };

  service_after = [ "postgresql.service" ];
  service_requires = [ "postgresql.service" ];
};
```

### Example 2: Using Procfile

```nix
services.rails-app.myapp-web = {
  enable = true;
  package = myapp.packages.x86_64-linux.package-with-bundix;
  procfile_role = "web";
  procfile_filename = "${myapp.packages.x86_64-linux.package-with-bundix}/app/Procfile";

  environment_overrides = {
    RAILS_ENV = "production";
    PORT = "3000";
  };
};
```

### Example 3: Multi-Role Deployment

```nix
services.rails-app = {
  # Web server
  shop-web = {
    enable = true;
    package = shop-app.packages.x86_64-linux.package-with-bundix;
    procfile_role = "web";
    procfile_filename = "${shop-app.packages.x86_64-linux.package-with-bundix}/app/Procfile";

    environment_overrides = {
      RAILS_ENV = "production";
      PORT = "3000";
    };

    service_after = [ "postgresql.service" "redis.service" ];
    service_requires = [ "postgresql.service" "redis.service" ];
  };

  # Background job worker
  shop-worker = {
    enable = true;
    package = shop-app.packages.x86_64-linux.package-with-bundix;
    procfile_role = "worker";
    procfile_filename = "${shop-app.packages.x86_64-linux.package-with-bundix}/app/Procfile";

    environment_overrides = {
      RAILS_ENV = "production";
      WORKER_COUNT = "5";
    };

    service_after = [ "rails-app-shop-web.service" ];
  };

  # Scheduled tasks
  shop-scheduler = {
    enable = true;
    package = shop-app.packages.x86_64-linux.package-with-bundix;
    command = "bundle exec clockwork config/schedule.rb";

    environment_overrides = {
      RAILS_ENV = "production";
    };

    service_after = [ "rails-app-shop-web.service" ];
  };
};
```

### Example 4: Secure Environment with AWS Parameter Store

```nix
services.rails-app.api-web = {
  enable = true;
  package = api-app.packages.x86_64-linux.package-with-bundix;
  command = "bundle exec puma -C config/puma.rb";

  # Fetch secrets from AWS Parameter Store at service start
  environment_command = ''
    ${pkgs.awscli2}/bin/aws ssm get-parameters-by-path \
      --path /api/production \
      --with-decryption \
      --query 'Parameters[*].[Name,Value]' \
      --output text | \
    sed 's|/api/production/||' | \
    awk '{print $1"="$2}'
  '';

  # Override specific values
  environment_overrides = {
    RAILS_ENV = "production";
    PORT = "8080";
  };
};
```

### Example 5: Hanami Application

```nix
services.rails-app.hanami-web = {
  enable = true;
  package = hanami-app.packages.x86_64-linux.package-with-bundix;
  command = "bundle exec hanami server -p 2300";

  environment_overrides = {
    HANAMI_ENV = "production";
    DATABASE_URL = "postgresql://localhost/hanami_production";
  };
};
```

### Example 6: Sinatra API

```nix
services.rails-app.sinatra-api = {
  enable = true;
  package = sinatra-app.packages.x86_64-linux.package-with-bundix;
  command = "bundle exec rackup -p 9292 -o 0.0.0.0";

  environment_overrides = {
    RACK_ENV = "production";
  };
};
```

## Service Management

### View service status
```bash
sudo systemctl status rails-app-myapp-web.service
```

### Start/stop/restart
```bash
sudo systemctl start rails-app-myapp-web.service
sudo systemctl stop rails-app-myapp-web.service
sudo systemctl restart rails-app-myapp-web.service
```

### View logs
```bash
# Follow logs
sudo journalctl -u rails-app-myapp-web.service -f

# Show last 100 lines
sudo journalctl -u rails-app-myapp-web.service -n 100

# Show logs since boot
sudo journalctl -u rails-app-myapp-web.service -b
```

### Enable/disable service
```bash
# Start on boot
sudo systemctl enable rails-app-myapp-web.service

# Don't start on boot
sudo systemctl disable rails-app-myapp-web.service
```

## Deployment Workflow

### Initial Deployment

```bash
# 1. Build and test your app locally
cd /path/to/your-rails-app
nix build .#package-with-bundix
./result/app/bin/rails --version  # Verify it works

# 2. Update NixOS configuration with your app as input
sudo nano /etc/nixos/flake.nix  # Add your app as input

# 3. Update NixOS flake lock
sudo nix flake update /etc/nixos

# 4. Deploy
sudo nixos-rebuild switch --flake /etc/nixos#myhostname

# 5. Verify service is running
sudo systemctl status rails-app-myapp-web.service
```

### Updating Your Application

```bash
# 1. Make changes to your app
cd /path/to/your-rails-app
# ... make changes ...
git commit -am "Update feature"

# 2. Update flake lock in NixOS config to get new version
cd /etc/nixos
sudo nix flake lock --update-input your-rails-app

# 3. Rebuild NixOS (this rebuilds your app and restarts the service)
sudo nixos-rebuild switch --flake /etc/nixos#myhostname
```

### Database Migrations

```bash
# Run migrations before deploying
cd /path/to/your-rails-app
nix develop .#with-bundix
rails db:migrate RAILS_ENV=production

# Or run migrations via systemd oneshot service (add to your config):
systemd.services.rails-app-myapp-migrate = {
  description = "Run Rails migrations for myapp";
  wantedBy = [ "rails-app-myapp-web.service" ];
  before = [ "rails-app-myapp-web.service" ];
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
    WorkingDirectory = "${myapp.packages.x86_64-linux.package-with-bundix}/app";
    ExecStart = "${pkgs.bash}/bin/bash -c 'cd ${myapp.packages.x86_64-linux.package-with-bundix}/app && bundle exec rails db:migrate'";
  };
};
```

## Troubleshooting

### Service won't start

```bash
# Check service status
sudo systemctl status rails-app-myapp-web.service

# Check logs
sudo journalctl -u rails-app-myapp-web.service -n 100

# Check if package built correctly
nix build .#package-with-bundix
ls -la result/app/
```

### Environment variables not working

```bash
# Check what environment the service sees
sudo systemctl show rails-app-myapp-web.service | grep Environment

# Test environment_command manually
${pkgs.awscli2}/bin/aws ssm get-parameters-by-path --path /myapp/prod
```

### Permission issues

The service runs as a dedicated user (`rails-app-<name>` by default). Make sure:

- Database allows connections from this user
- File permissions are correct for mutable directories
- Sockets/ports are accessible

```bash
# Check which user the service runs as
sudo systemctl show rails-app-myapp-web.service | grep User

# Check directory permissions
ls -la /var/lib/rails-app-myapp-web/
ls -la /var/log/rails-app-myapp-web/
```

## Security Considerations

1. **Never put secrets in environment_overrides** - Use `environment_command` to fetch from a secrets manager
2. **Use systemd's security features** - The module automatically sets:
   - `NoNewPrivileges = true`
   - `PrivateTmp = true`
   - `ProtectSystem = "strict"`
   - `ProtectHome = true`

3. **Run as dedicated user** - Each service instance runs as its own user by default
4. **Secrets are never written to disk** - Environment variables loaded at runtime only

## Advanced: Custom Working Directory

By default, the service runs from the immutable Nix store path. If you need a custom working directory:

```nix
services.rails-app.myapp-web = {
  enable = true;
  package = myapp.packages.x86_64-linux.package-with-bundix;

  # Custom working directory
  service_config_extra = {
    WorkingDirectory = "/custom/path";
  };
};
```

## Complete Production Example

```nix
# /etc/nixos/flake.nix
{
  description = "Production Rails Server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    shop-app = {
      url = "github:mycompany/shop-app";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rails-builder.url = "github:glenndavy/rails-builder";
  };

  outputs = { self, nixpkgs, shop-app, rails-builder, ... }: {
    nixosConfigurations.production-web = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hardware-configuration.nix
        rails-builder.nixosModules.rails-app

        ({ pkgs, ... }: {
          # PostgreSQL
          services.postgresql = {
            enable = true;
            ensureDatabases = [ "shop_production" ];
            ensureUsers = [{
              name = "shop";
              ensureDBOwnership = true;
            }];
          };

          # Redis
          services.redis.servers."" = {
            enable = true;
            bind = "127.0.0.1";
          };

          # Nginx reverse proxy
          services.nginx = {
            enable = true;
            recommendedProxySettings = true;
            recommendedTlsSettings = true;

            virtualHosts."shop.example.com" = {
              enableACME = true;
              forceSSL = true;
              locations."/" = {
                proxyPass = "http://127.0.0.1:3000";
              };
            };
          };

          # Rails app - Web server
          services.rails-app.shop-web = {
            enable = true;
            package = shop-app.packages.x86_64-linux.package-with-bundix;
            procfile_role = "web";
            procfile_filename = "${shop-app.packages.x86_64-linux.package-with-bundix}/app/Procfile";

            environment_command = ''
              ${pkgs.awscli2}/bin/aws ssm get-parameters-by-path \
                --path /shop/production \
                --with-decryption \
                --query 'Parameters[*].[Name,Value]' \
                --output text | \
              sed 's|/shop/production/||' | \
              awk '{print $1"="$2}'
            '';

            environment_overrides = {
              RAILS_ENV = "production";
              PORT = "3000";
              DATABASE_URL = "postgresql://shop@localhost/shop_production";
              REDIS_URL = "redis://127.0.0.1:6379/0";
            };

            service_after = [ "postgresql.service" "redis.service" ];
            service_requires = [ "postgresql.service" "redis.service" ];
          };

          # Rails app - Background worker
          services.rails-app.shop-worker = {
            enable = true;
            package = shop-app.packages.x86_64-linux.package-with-bundix;
            procfile_role = "worker";
            procfile_filename = "${shop-app.packages.x86_64-linux.package-with-bundix}/app/Procfile";

            environment_command = services.rails-app.shop-web.environment_command;
            environment_overrides = services.rails-app.shop-web.environment_overrides;

            service_after = [ "rails-app-shop-web.service" ];
          };

          # Firewall
          networking.firewall.allowedTCPPorts = [ 80 443 ];
        })
      ];
    };
  };
}
```

## See Also

- [Main README](README.md) - Rails-builder overview
- [NixOS Module Implementation](nixos-modules/rails-app.nix) - Module source code
- [Template Documentation](templates/universal/README.md) - Flake template usage
