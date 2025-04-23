{ config, lib, pkgs, ... }: {
  systemd.services.myRailsApp = {
    description = "My Rails App";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      User = "deploy";
      WorkingDirectory = config.deployment.railsApp;
      ExecStart = "${config.deployment.railsApp}/bin/bundle exec puma -C config/puma.rb";
    };
  };
}
