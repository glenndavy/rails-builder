# Test specific parameters to bundix build
{
  pkgs,
  rubyVersion,
  gccVersion ? "latest", 
  opensslVersion ? "3_2",
  src ? ./.,
  buildRailsApp,
  gems,
  nodeModules,
  universalBuildInputs,
  rubyPackage,
  rubyMajorMinor,
  yarnOfflineCache,
  gccPackage,
  opensslPackage,
  usrBinDerivation,
  tzinfo,
  defaultShellHook,
  ...
}:

# Test each parameter type and their string interpolations
pkgs.writeText "test-params" ''
  Parameter Types:
  gems type: ${builtins.typeOf gems}
  rubyMajorMinor type: ${builtins.typeOf rubyMajorMinor}
  rubyMajorMinor value: ${rubyMajorMinor}
  
  String interpolation tests:
  gems toString: ${toString gems}
  rubyMajorMinor: ${rubyMajorMinor}
  
  Path tests:
  gems/lib path: ${gems}/lib/ruby/gems/${rubyMajorMinor}.0
''