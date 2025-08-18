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
    system = "x86_64-linux";
    version = "2.0.58";
    overlays = [nixpkgs-ruby.overlays.default];
    pkgs = import nixpkgs {inherit system overlays;};
    mkRailsBuild = import ./derivations/make-rails-build.nix {inherit pkgs;};
    mkRailsNixBuild = import ./derivations/make-rails-nix-build.nix {inherit pkgs;};
  in {
    lib = {
      inherit mkRailsBuild mkRailsNixBuild;
      version = version;
    };
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
