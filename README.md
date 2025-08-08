
## What is this

This offers an approach to building rails apps that can be slotted into the [new stack](..).


It uses nixpkgs (so, could be run on nixos, ubuntu+nixpkgs, darwin+nixpkgs), to declare and create a closure from a fairly typical bundler&assets type rails 'build'.  

This closure can the be applied into a nixbuild (via nixos, darwin or ubuntu) to an ec2 instance, or turned into a docker, or qcow or other image; thus giving us flexibiilty as the broader product evolves. 


## Why this

Similar to buildpacks, this gives us an autodetect based solution which aims to discover and deploy its own dependencies, while also giving us the opportunities to add overriding hooks.

Beyond the varencies of the rails stack itself it provide a highly reproducable environement.

It also give us a mechanism to provide a variety of outputs based on the same build process. 

Finally, the docker image we can produce this way is very thing.

As an aside, this isn't producing a pure nix build (via bundix/nodeix etc) , as doing this for a generalised impure ecosystem like rails becomes difficult, though perhaps when there's time and its considerd worth doing. 


## How this happens

I envisage that we will be calling this via AWS code builder, though could be manually or GH actions. 

On a fresh (freshness here is up for discussion) ec2 instance, we:
+ build stage 1:
    + load context (mechanism to do), This tells us about the 
        + Git location
        + Destination Format (just do a build, create a docker image, or other not yet implemented)
        + bundix approach or other ? 
        + location of ecr or other artifact destination?
    + checkout the code 
    + Install and launch build-stage-2
+ build stage 2:
    + instantiate the [[templates/new-app/flake.nix]]
    + create the prepare-build script
    + use the nix flake to provide a shell then
        + add postgres, redis, do run prepare build to add ruby and other dependencies
        + do the standard rails things (bundle, assets etc).
    + call build stage 3 to make the artifact, and push it


## Other things
### Handy snippets

```
nix show-derivation .#buildRailsApp
```


# dependency chain

---
inputs:
  source
  nix
  rubyVersions
  bundlerHashes?
  
apps:
  detectRubyVersion 
  detectBundlerVersion
  detectNodeVersion
  ? detectPgVersion 
  detectOpenSSL version

vars
  corePackages

context  derivations:
  rubyPackage
  bundleVersio <- bundlerHahses
  nodeVersion
  usrBin
  tzinfo 
  ? pgVersion
  openSSL_Legacy
  openSSPackage

libs:
  prepare-rails-app
  make-rails-app 
  shell-environment
scripts
  <- lib/prepare-rails-app
  <- lib/makee-rails-app

shells
  minimal-shell
     <-corePackages
     <- BUNDLER_PATH etc
     <- caCerts

  devShell    
    <- manage postgres for rails
    <- manage redis for rails
    <- minimal-shel

  makeShell
    <- devShell 
    <- ???

packages
  classic
    railsPackage
      <- source 
      <- corePackages
      <- Shell environemnt
      <- rubyVersion
      <- bundlerVersion
      <- nodeVersion
      <- tzinfo ? 
      ssl? 
      caCert?

    dockerImage
       <- railsPackage
       <- usrBin
       <- tzinfo 

    railsAppModule
       <- railsPackage
       <- systemd 
       <-
  pure
     - overrides:
       make-rails-app 
     - railsPackage
         <- bundix, bundlerEnv
         <- node2nix <- ??
     - dockerImage 
        <- pure.railsPackage
        <- usrBin
        <- tzinfo 
     - railsAppModules
          <- railsPackage
          <- systemd 
#### footnotes

* impure here means that due to external dependencies including network access of various gems, its not always possible to build a repeatable build. This isn't a problem whem taking this approach for a product that  you own because you can manage this, but for a generalised 'just works' effort, this is tricky. 
