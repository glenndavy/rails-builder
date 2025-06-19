{
  config,
  pkgs,
  ...
}: {
  # Enable Nix flakes
  nix.settings.experimental-features = ["nix-command" "flakes"];
  # Create app-builder user
  users.users.app-builder = {
    isNormalUser = true;
    uid = 1000;
    group = "app-builder";
    home = "/home/app-builder";
    shell = pkgs.bash;
  };
  users.groups.app-builder = {
    gid = 1000;
  };
  # Install essential packages
  environment.systemPackages = with pkgs; [
    curl
    git
    build-essential
    ca-certificates
    postgresql
    redis
  ];
  # Allow insecure packages
  nixpkgs.config.allowInsecure = true;
}
