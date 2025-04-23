{
  description = "My Rails App Flake";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rails-flake.url = "path/to/your/rails-flake";
  };
  outputs = { self, nixpkgs, rails-flake }: let
    system = "x86_64-linux";
    rubyVersion = "3_0_2";
    src = ./.; # Your Rails app directory
    gems = [ "rails" "puma" ];
    railsApp = rails-flake.lib.buildRailsApp { inherit system rubyVersion src gems; };
  in {
    packages.${system}.railsApp = railsApp;
    nixosModules.myRailsApp = rails-flake.lib.nixosModule { inherit railsApp; };
    packages.${system}.dockerImage = rails-flake.lib.dockerImage { inherit system railsApp; };
  };
}
