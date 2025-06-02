#!/bin/bash
set -e
git checkout -b builder
cp /path/to/template-flake.nix flake.nix
docker run -it --rm -u $(id -u):$(id -g) -v $(pwd):/builder -w /builder -e HOME=/builder nixos/nix bash -c "
  nix develop .#buildShell --extra-experimental-features 'nix-command flakes' &&
  bundle install &&
  bundle pristine curb &&
  bundle exec rails assets:precompile &&
  nix build .#buildApp &&
  nix build .#dockerImage
"
docker load < result
