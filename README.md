
## Handy snippets

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
  rubyVersion
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
