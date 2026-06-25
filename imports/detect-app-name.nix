# imports/detect-app-name.nix
#
# Auto-detect application name from source files.
#   - Rails:      config/application.rb  →  `module Foo`
#   - Hanami 2.x: config/app.rb          →  `module Foo`
#   - Hanami 1.x: not auto-detectable (no canonical module-name file);
#                 caller should fall back to "hanami-app".
#
# Module name is then converted to kebab-case.
#   "module OpsCore"      → "ops-core"
#   "module MyRailsApp"   → "my-rails-app"
#
{
  detectAppName = { src, framework ? "ruby" }:
    let
      # CamelCase → kebab-case. OpsCore → ops-core, MyRailsApp → my-rails-app.
      toKebabCase = str:
        let
          len = builtins.stringLength str;
          lowerMap = {
            A = "a"; B = "b"; C = "c"; D = "d"; E = "e"; F = "f"; G = "g";
            H = "h"; I = "i"; J = "j"; K = "k"; L = "l"; M = "m"; N = "n";
            O = "o"; P = "p"; Q = "q"; R = "r"; S = "s"; T = "t"; U = "u";
            V = "v"; W = "w"; X = "x"; Y = "y"; Z = "z";
          };
          processIdx = idx:
            let
              char = builtins.substring idx 1 str;
              isUpper = builtins.match "[A-Z]" char != null;
              lowerChar = if isUpper then lowerMap.${char} else char;
            in
              if isUpper && idx > 0
              then "-${lowerChar}"
              else lowerChar;
          chars = builtins.genList processIdx len;
        in builtins.concatStringsSep "" chars;

      # Read a file and pull the first `module Foo` declaration out of it.
      # Returns null if file missing or no module line found.
      parseModuleName = path:
        if !(builtins.pathExists path)
        then null
        else
          let
            content = builtins.readFile path;
            splitLines = builtins.split "\n" content;
            stringLines = builtins.filter builtins.isString splitLines;
            moduleLines = builtins.filter
              (line: builtins.match "^module [A-Z].*" line != null)
              stringLines;
            moduleLine =
              if builtins.length moduleLines > 0
              then builtins.head moduleLines
              else null;
          in
            if moduleLine == null
            then null
            else
              let
                # Drop "module " prefix (7 chars), split on space, take first token.
                withoutPrefix = builtins.substring 7
                  (builtins.stringLength moduleLine - 7)
                  moduleLine;
                parts = builtins.split " " withoutPrefix;
                firstPart = builtins.head (builtins.filter builtins.isString parts);
              in
                if firstPart == "" then null else firstPart;

      moduleSourceFile =
        if framework == "rails"  then src + "/config/application.rb"
        else if framework == "hanami" then src + "/config/app.rb"
        else null;

      moduleName =
        if moduleSourceFile == null
        then null
        else parseModuleName moduleSourceFile;
    in
      if moduleName == null then null else toKebabCase moduleName;
}
