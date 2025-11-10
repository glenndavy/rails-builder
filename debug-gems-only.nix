# Test just the gems parameter
{
  pkgs,
  rubyPackage,
  bundlerVersion,
  name ? "rails-gems",
  gemdir,
  gemset,
  autoFix ? true,
  buildInputs ? [],
  gemConfig ? {},
  ...
}@args:

# Just return the gems parameter type info
pkgs.writeText "gems-debug" ''
  Gems Debug Info:
  autoFix: ${toString autoFix}
  autoFix type: ${builtins.typeOf autoFix}
  gemConfig type: ${builtins.typeOf gemConfig}
  gemset path: ${toString gemset}
''