{ lib, gemConfig, stdenv, ... }:

let
  inherit (lib)
    attrValues
    concatMap
    converge
    filterAttrs
    getAttrs
    intersectLists
    ;

in
rec {
  bundlerFiles =
    {
      gemfile ? null,
      lockfile ? null,
      gemset ? null,
      gemdir ? null,
      ...
    }:
    {
      inherit gemdir;

      gemfile =
        if gemfile == null then
          assert gemdir != null;
          gemdir + "/Gemfile"
        else
          gemfile;

      lockfile =
        if lockfile == null then
          assert gemdir != null;
          gemdir + "/Gemfile.lock"
        else
          lockfile;

      gemset =
        if gemset == null then
          assert gemdir != null;
          gemdir + "/gemset.nix"
        else
          gemset;
    };

  filterGemset =
    { ruby, groups, ... }:
    gemset:
    let
      platformGems = filterAttrs (_: platformMatches ruby) gemset;
      directlyMatchingGems = filterAttrs (_: groupMatches groups) platformGems;

      expandDependencies =
        gems:
        let
          depNames = concatMap (gem: gem.dependencies or [ ]) (attrValues gems);
          deps = getAttrs depNames platformGems;
        in
        gems // deps;
    in
    converge expandDependencies directlyMatchingGems;

  platformMatches =
    { rubyEngine, version, ... }:
    attrs:
    (
      !(attrs ? platforms)
      || builtins.length attrs.platforms == 0
      || builtins.any (
        platform:
        platform.engine == rubyEngine && (!(platform ? version) || platform.version == version.majMin)
      ) attrs.platforms
    );

  groupMatches =
    groups: attrs:
    groups == null
    || !(attrs ? groups)
    || (intersectLists (groups ++ [ "default" ]) attrs.groups) != [ ];

  applyGemConfigs =
    attrs: (if gemConfig ? ${attrs.gemName} then attrs // gemConfig.${attrs.gemName} attrs else attrs);

  genStubsScript =
    {
      lib,
      runCommand,
      ruby,
      confFiles,
      bundler,
      groups,
      binPaths,
      ...
    }:
    let
      genStubsScript =
        runCommand "gen-bin-stubs"
          {
            strictDeps = true;
            nativeBuildInputs = [ ruby ];
          }
          ''
            cp ${./gen-bin-stubs.rb} $out
            chmod +x $out
            patchShebangs --build $out
          '';
    in
    ''
      ${genStubsScript} \
        "${ruby}/bin/ruby" \
        "${confFiles}/Gemfile" \
        "$out/${ruby.gemPath}" \
        "${bundler}/${ruby.gemPath}/gems/bundler-${bundler.version}" \
        ${lib.escapeShellArg binPaths} \
        ${lib.escapeShellArg groups}
    '';

  pathDerivation =
    {
      gemName,
      version,
      path,
      ruby,
      gemdir,
      ...
    }@attrs:
    let
      # Resolve path relative to gemdir if it's a string
      resolvedPath = if builtins.isString path then gemdir + ("/" + path) else path;

      # Detect if this is a git gem from vendor/cache by checking path
      isVendorCacheGitGem = lib.hasInfix "/vendor/cache/" (toString resolvedPath);
      gemDirName = builtins.baseNameOf (toString resolvedPath);

      # Build actual derivation that copies the gem source
      drv = stdenv.mkDerivation {
        pname = gemName;
        inherit version;

        src = resolvedPath;

        # vendor/cache contains already-unpacked directories, not archives
        dontUnpack = true;
        dontBuild = true;
        dontStrip = true;
        dontPatchShebangs = true;

        installPhase = ''
          mkdir -p $out/lib/ruby/gems/${ruby.version.majMin}.0/gems
          cp -r $src $out/lib/ruby/gems/${ruby.version.majMin}.0/gems/${gemDirName}

          # For vendor/cache git gems, also create bundler/gems symlink
          ${lib.optionalString isVendorCacheGitGem ''
            mkdir -p $out/lib/ruby/gems/${ruby.version.majMin}.0/bundler/gems
            ln -sf ../../gems/${gemDirName} $out/lib/ruby/gems/${ruby.version.majMin}.0/bundler/gems/${gemDirName}
          ''}
        '';
      };
    in
    drv // {
      bundledByPath = true;
      suffix = version;
      gemType = "path";
    };

  composeGemAttrs =
    ruby: gems: name: attrs:
    (
      (removeAttrs attrs [ "platforms" ])
      // {
        inherit ruby;
        inherit (attrs.source) type;
        source = removeAttrs attrs.source [ "type" ];
        gemName = name;
        gemPath = map (gemName: gems.${gemName}) (attrs.dependencies or [ ]);
      }
    );
}
