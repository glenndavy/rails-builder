# In rails-builder flake.nix
{
  description = "Generic Rails builder flake";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = {
    self,
    nixpkgs,
    nixpkgs-ruby,
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    version = "2.0.58";
    forAllSystems = nixpkgs.lib.genAttrs systems;
    overlays = [nixpkgs-ruby.overlays.default];

    mkPkgsForSystem = system: import nixpkgs {inherit system overlays;};
    mkLibForSystem = system: let
      pkgs = mkPkgsForSystem system;
      mkRailsBuild = import ./derivations/make-rails-build.nix {inherit pkgs;};
      mkRailsNixBuild = import ./derivations/make-rails-nix-build.nix {inherit pkgs;};
    in {
      inherit mkRailsBuild mkRailsNixBuild;
      version = version;
    };
  in {
    lib = forAllSystems mkLibForSystem;
    templates.new-app = {
      path = ./templates/new-app;
      description = "A template for a Rails application";
    };
    templates.build-rails = {
      path = ./templates/build-rails;
      description = "A template for building rails";
    };
    templates.build-rails-with-nix = {
      path = ./templates/build-rails-with-nix;
      description = "A template for building rails with nix";
    };
  };
}
