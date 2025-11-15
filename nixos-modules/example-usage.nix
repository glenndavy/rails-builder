# Example usage of the universal Ruby NixOS module
# Can be imported as any framework-specific alias for clarity
{
  imports = [
    ./rails-app.nix  # The actual module file
  ];

  # Note: In a real flake, you'd import like:
  # rails-builder.nixosModules.rails-app    # For Rails
  # rails-builder.nixosModules.hanami-app   # For Hanami
  # rails-builder.nixosModules.sinatra-app  # For Sinatra
  # rails-builder.nixosModules.rack-app     # For Rack
  # rails-builder.nixosModules.ruby-app     # Generic

  # Example: Multi-role Rails deployment
  services.rails-app = {
    # Web server instance
    web = {
      enable = true;
      package = myRailsApp; # Your Rails application package

      # Option A: Direct command
      command = "bundle exec rails server -p 3000";

      # Option B: Procfile-based (alternative to direct command)
      # procfile_role = "web";
      # procfile_filename = "${myRailsApp}/app/Procfile";

      # Environment setup
      environment_command = ''
        aws ssm get-parameters-by-path \
          --path /myapp/prod \
          --recursive \
          --with-decryption \
          --query 'Parameters[*].[Name,Value]' \
          --output text | \
        sed 's|.*/||' | \
        sed 's/\t/=/' | \
        sed 's/^/export /'
      '';

      environment_overrides = {
        RAILS_ENV = "production";
        PORT = "3000";
        RAILS_SERVE_STATIC_FILES = "true";
      };

      # Service configuration
      service_description = "MyApp Web Server";
      service_after = [ "postgresql.service" "redis.service" "network.target" ];
      service_requires = [ "postgresql.service" ];

      # Custom lifecycle commands
      stop_command = "/bin/kill -TERM $MAINPID";
      restart_command = "/bin/kill -USR1 $MAINPID";

      # Mutable directories (defaults are usually fine)
      mutable_dirs = {
        tmp = "/var/lib/myapp-web/tmp";
        log = "/var/log/myapp-web";
        storage = "/var/lib/myapp-web/storage";
        public = "/var/lib/myapp-web/public"; # For uploaded assets
      };
    };

    # Background worker instance
    worker = {
      enable = true;
      package = myRailsApp;

      procfile_role = "worker";
      procfile_filename = "${myRailsApp}/app/Procfile";

      # Shared environment setup (could be abstracted to a function)
      environment_command = ''
        aws ssm get-parameters-by-path \
          --path /myapp/prod \
          --recursive \
          --with-decryption \
          --query 'Parameters[*].[Name,Value]' \
          --output text | \
        sed 's|.*/||' | \
        sed 's/\t/=/' | \
        sed 's/^/export /'
      '';

      environment_overrides = {
        RAILS_ENV = "production";
        WORKER_THREADS = "10";
      };

      service_description = "MyApp Background Worker";
      service_after = [ "postgresql.service" "redis.service" "rails-app-web.service" ];
      service_requires = [ "postgresql.service" "redis.service" ];

      mutable_dirs = {
        tmp = "/var/lib/myapp-worker/tmp";
        log = "/var/log/myapp-worker";
      };
    };

    # Scheduled tasks instance
    scheduler = {
      enable = true;
      package = myRailsApp;

      command = "bundle exec clockwork config/schedule.rb";

      environment_command = ''
        aws ssm get-parameters-by-path \
          --path /myapp/prod \
          --recursive \
          --with-decryption \
          --query 'Parameters[*].[Name,Value]' \
          --output text | \
        sed 's|.*/||' | \
        sed 's/\t/=/' | \
        sed 's/^/export /'
      '';

      environment_overrides = {
        RAILS_ENV = "production";
      };

      service_description = "MyApp Scheduler";
      service_after = [ "postgresql.service" "redis.service" ];
      service_requires = [ "postgresql.service" ];
    };
  };

  # Example: Single-role deployment (just web server)
  services.rails-app.simple-web = {
    enable = true;
    package = mySimpleApp;
    command = "bundle exec rails server -p 4000";

    environment_overrides = {
      RAILS_ENV = "production";
      PORT = "4000";
    };

    service_description = "Simple Rails App";
  };

  # Example: Development/staging with simpler environment
  services.rails-app.staging = {
    enable = true;
    package = myStagingApp;

    procfile_role = "web";
    procfile_filename = "${myStagingApp}/app/Procfile";

    environment_overrides = {
      RAILS_ENV = "staging";
      RAILS_LOG_LEVEL = "debug";
    };

    service_description = "Staging Environment";
  };
}