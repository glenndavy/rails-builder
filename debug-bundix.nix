# Minimal test to isolate the boolean parameter
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

# Test each parameter type
pkgs.writeText "debug-bundix" ''
  Parameter Types:
  gems: ${builtins.typeOf gems}
  rubyMajorMinor: ${builtins.typeOf rubyMajorMinor} = ${rubyMajorMinor}
  yarnOfflineCache: ${builtins.typeOf yarnOfflineCache}
  nodeModules: ${builtins.typeOf nodeModules}
  gccPackage: ${builtins.typeOf gccPackage}
  opensslPackage: ${builtins.typeOf opensslPackage}
  usrBinDerivation: ${builtins.typeOf usrBinDerivation}
  tzinfo: ${builtins.typeOf tzinfo}
  rubyPackage: ${builtins.typeOf rubyPackage}
  
  String Values:
  gems toString: ${toString gems}
  rubyMajorMinor: ${rubyMajorMinor}
''