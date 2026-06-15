{
  stdenv,
  lib,
  buildPackages,
  runCommand,
  ruby,
  defaultGemConfig,
  buildRubyGem,
  buildEnv,
  makeBinaryWrapper,
  bundler,
}@defs:

{
  name ? null,
  pname ? null,
  version ? null,
  mainGemName ? null,
  gemdir ? null,
  gemfile ? null,
  lockfile ? null,
  gemset ? null,
  ruby ? defs.ruby,
  copyGemFiles ? false, # Copy gem files instead of symlinking
  gemConfig ? defaultGemConfig,
  postBuild ? null,
  document ? [ ],
  meta ? { },
  groups ? null,
  ignoreCollisions ? false,
  nativeBuildInputs ? [ ],
  buildInputs ? [ ],
  extraConfigPaths ? [ ],
  passthru ? { },
  ...
}@args:

assert name == null -> pname != null;

let
  functions = import ./functions.nix { inherit lib gemConfig stdenv; };

  inherit (functions)
    applyGemConfigs
    bundlerFiles
    composeGemAttrs
    filterGemset
    genStubsScript
    pathDerivation
    ;

  gemFiles = bundlerFiles args;

  importedGemset =
    if builtins.typeOf gemFiles.gemset != "set" then import gemFiles.gemset else gemFiles.gemset;

  filteredGemset = filterGemset { inherit ruby groups; } importedGemset;

  configuredGemset = lib.flip lib.mapAttrs filteredGemset (
    name: attrs:
    applyGemConfigs (
      attrs
      // {
        inherit ruby document;
        gemName = name;
      }
    )
  );

  hasBundler = builtins.hasAttr "bundler" filteredGemset;

  # Fallback bundler when gemset.nix doesn't include `bundler`. The naive
  # `defs.bundler.override { inherit ruby; }` uses nixpkgs' current bundler
  # (2.7+), which calls `Module#method_defined?(name, inherit)` — a Ruby 3.0+
  # API. Older Rails apps pinning Ruby <3.0 crash at require-time. Pin to
  # bundler 2.3.26 (last 2.x that supports Ruby 2.5+) when the project's
  # Ruby is too old for the modern default. Callers can still override via
  # the `bundler` callPackage arg if they need a specific version.
  bundlerForRuby =
    let
      rubyVer = ruby.version;
      isOldRuby = lib.versionOlder rubyVer "3.0";
    in
      if isOldRuby
      then defs.buildRubyGem {
        inherit ruby;
        gemName = "bundler";
        version = "2.3.26";
        source.sha256 = "02cyk6pfknz2y01n5s485r1dalc5rp7hdzyvqs1asa77c7gkrr8y";
        sha256 = "02cyk6pfknz2y01n5s485r1dalc5rp7hdzyvqs1asa77c7gkrr8y";
      }
      else defs.bundler.override (attrs: {
        inherit ruby;
      });

  bundler =
    if hasBundler then
      gems.bundler
    else
      bundlerForRuby;

  gems = lib.flip lib.mapAttrs configuredGemset (name: attrs: buildGem name attrs);

  version' =
    if version != null then
      version
    else if pname != null then
      gems.${pname}.suffix
    else
      null;

  name' = if name != null then name else "${pname}-${version'}";

  pname' = if pname != null then pname else name;

  copyIfBundledByPath =
    {
      bundledByPath ? false,
      ...
    }:
    (lib.optionalString bundledByPath (
      assert gemFiles.gemdir != null;
      "cp -a ${gemFiles.gemdir}/* $out/"
    ) # */
    );

  maybeCopyAll =
    pkgname:
    lib.optionalString (pkgname != null) (
      let
        mainGem = gems.${pkgname} or (throw "bundlerEnv: gem ${pkgname} not found");
      in
      copyIfBundledByPath mainGem
    );

  # We have to normalize the Gemfile.lock, otherwise bundler tries to be
  # helpful by doing so at run time, causing executables to immediately bail
  # out. Yes, I'm serious.
  confFiles = runCommand "gemfile-and-lockfile" { } ''
    mkdir -p $out
    ${maybeCopyAll mainGemName}
    cp ${gemFiles.gemfile} $out/Gemfile || ls -l $out/Gemfile
    cp ${gemFiles.lockfile} $out/Gemfile.lock || ls -l $out/Gemfile.lock

    ${lib.concatMapStringsSep "\n" (path: "cp -r ${path} $out/") extraConfigPaths}
  '';

  # Strip bundler's git-source bookkeeping from each gem's output. When
  # multiple gems originate from the same git source (e.g. the Rails
  # monorepo: railties + activerecord + actionmailer + ... all from
  # github:rails/rails), every constituent gem ends up carrying its own
  # copy of `lib/ruby/gems/X.Y.Z/cache/bundler/git/<repo>-<sha>/index`
  # at the same logical path. buildEnv then refuses to merge them with
  # "two given paths contain a conflicting subpath".
  #
  # The cache files are bundler's local bookkeeping — irrelevant in a
  # pre-resolved Nix env where bundle won't be re-fetching from git.
  stripBundlerGitCachePostInstall = ''
    # 1. Bundler's per-repo cache index — colliding sibling for multi-gem
    #    git sources (Rails monorepo: railties + activerecord + …).
    find $out -type d -path '*/cache/bundler/git' -exec rm -rf {} + 2>/dev/null || true
    # 2. The cloned source tree's own .git/ dir under bundler/gems/<repo>/.
    #    Same multi-gem-from-one-git collision at .git/index, .git/HEAD, etc.
    #    The Nix store gem dir doesn't need git metadata at runtime.
    find $out -type d -path '*/bundler/gems/*/.git' -exec rm -rf {} + 2>/dev/null || true
  '';
  appendStripCache = a: a // {
    postInstall = (a.postInstall or "") + "\n" + stripBundlerGitCachePostInstall;
  };

  buildGem =
    name: attrs:
    (
      let
        gemAttrs = composeGemAttrs ruby gems name attrs;
      in
      if gemAttrs.type == "path" then
        pathDerivation (gemAttrs.source // gemAttrs // { gemdir = gemFiles.gemdir; })
      else if gemAttrs.source ? path then
        # Vendored .gem archive — pass as src so buildRubyGem skips rubygems.org
        # fetch. builtins.path coerces the resolved path to a Nix path value so
        # mkDerivation registers it as a build input (a bare string concat
        # would leave the .gem file outside the build sandbox).
        #
        # The store-path NAME must end in ".gem" because buildRubyGem's
        # unpackPhase dispatches on `$src == *.gem` to invoke its gem-aware
        # extractor — otherwise it falls through to stdenv's generic unpackFile
        # which doesn't know how to unpack a .gem archive.
        let
          p = gemAttrs.source.path;
          # Strip trailing "/." from gemdir (path: flake-input quirk) and
          # leading "./" from p (generate-dependencies writes "./vendor/...").
          gemdirStr = lib.removeSuffix "/." (toString gemFiles.gemdir);
          pStr = lib.removePrefix "./" (if builtins.isString p then p else toString p);
          resolved = builtins.path {
            path = gemdirStr + "/" + pStr;
            name = "${name}-${attrs.version}.gem";
          };
        in
        buildRubyGem (appendStripCache (gemAttrs // { src = resolved; }))
      else
        buildRubyGem (appendStripCache gemAttrs)
    );

  envPaths = lib.attrValues gems ++ lib.optional (!hasBundler) bundler;

  basicEnvArgs = {
    inherit
      nativeBuildInputs
      buildInputs
      ignoreCollisions
      pname
      ;

    name = name';
    version = version';

    paths = envPaths;
    pathsToLink = [ "/lib" ];

    postBuild =
      genStubsScript (
        defs
        // args
        // {
          inherit confFiles bundler groups;
          binPaths = envPaths;
        }
      )
      + lib.optionalString (postBuild != null) postBuild;

    meta = {
      platforms = ruby.meta.platforms;
    }
    // meta;

    passthru = (
      lib.optionalAttrs (pname != null) {
        inherit (gems.${pname}) gemType;
      }
      // rec {
        inherit
          ruby
          bundler
          gems
          confFiles
          envPaths
          ;

        wrappedRuby = stdenv.mkDerivation {
          name = "wrapped-ruby-${pname'}";

          nativeBuildInputs = [ makeBinaryWrapper ];

          dontUnpack = true;

          buildPhase = ''
            mkdir -p $out/bin
            for i in ${ruby}/bin/*; do
              makeWrapper "$i" $out/bin/$(basename "$i") \
                --set BUNDLE_GEMFILE ${confFiles}/Gemfile \
                --unset BUNDLE_PATH \
                --set BUNDLE_FROZEN 1 \
                --set GEM_HOME ${basicEnv}/${ruby.gemPath} \
                --set GEM_PATH ${basicEnv}/${ruby.gemPath}
            done
          '';

          dontInstall = true;

          doCheck = true;
          checkPhase = ''
            $out/bin/ruby --help > /dev/null
          '';

          inherit (ruby) meta;
        };

        env =
          let
            irbrc = builtins.toFile "irbrc" ''
              if !(ENV["OLD_IRBRC"].nil? || ENV["OLD_IRBRC"].empty?)
                require ENV["OLD_IRBRC"]
              end
              require 'rubygems'
              require 'bundler/setup'
            '';
          in
          stdenv.mkDerivation {
            name = "${pname'}-interactive-environment";
            nativeBuildInputs = [
              wrappedRuby
              basicEnv
            ];
            shellHook = ''
              export OLD_IRBRC=$IRBRC
              export IRBRC=${irbrc}
            '';
            buildCommand = ''
              echo >&2 ""
              echo >&2 "*** Ruby 'env' attributes are intended for interactive nix-shell sessions, not for building! ***"
              echo >&2 ""
              exit 1
            '';
          };
      }
      // passthru
    );
  };

  basicEnv =
    if copyGemFiles then
      runCommand name' basicEnvArgs ''
        mkdir -p $out
        for i in $paths; do
          ${buildPackages.rsync}/bin/rsync -a $i/lib $out/
        done
        eval "$postBuild"
      ''
    else
      buildEnv basicEnvArgs;
in
basicEnv
