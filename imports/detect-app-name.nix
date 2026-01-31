# imports/detect-app-name.nix
#
# Auto-detect application name from source files.
# For Rails apps, extracts the module name from config/application.rb
# and converts it to a kebab-case name suitable for Nix derivations.
#
# Example: "module OpsCore" -> "ops-core"
#          "module MyRailsApp" -> "my-rails-app"
#
{
  # Detect app name from Rails config/application.rb
  # Returns null if not found or not a Rails app
  detectAppName = { src, framework ? "ruby" }:
    let
      applicationRbPath = src + "/config/application.rb";
      hasApplicationRb = builtins.pathExists applicationRbPath;

      # Read and parse config/application.rb for Rails apps
      appNameFromRails =
        if framework == "rails" && hasApplicationRb
        then
          let
            content = builtins.readFile applicationRbPath;
            # builtins.split returns mix of strings and lists, filter strings first
            splitLines = builtins.split "\n" content;
            stringLines = builtins.filter builtins.isString splitLines;
            # Find lines matching "module SomeName"
            moduleLines = builtins.filter
              (line: builtins.match "^module [A-Z].*" line != null)
              stringLines;
            # Extract first matching line
            moduleLine = if builtins.length moduleLines > 0
              then builtins.head moduleLines
              else null;
            # Extract module name from "module FooBar" -> "FooBar"
            moduleName =
              if moduleLine != null
              then
                let
                  # Remove "module " prefix (7 characters)
                  withoutPrefix = builtins.substring 7 (builtins.stringLength moduleLine - 7) moduleLine;
                  # Split on space/comment and take first part
                  parts = builtins.split " " withoutPrefix;
                  firstPart = builtins.head (builtins.filter builtins.isString parts);
                in firstPart
              else null;

            # Convert CamelCase to kebab-case
            # OpsCore -> ops-core, MyRailsApp -> my-rails-app
            toKebabCase = str:
              let
                len = builtins.stringLength str;
                # Process each character
                processIdx = idx:
                  let
                    char = builtins.substring idx 1 str;
                    isUpper = builtins.match "[A-Z]" char != null;
                    # Map uppercase to lowercase
                    lowerMap = {
                      A = "a"; B = "b"; C = "c"; D = "d"; E = "e"; F = "f"; G = "g";
                      H = "h"; I = "i"; J = "j"; K = "k"; L = "l"; M = "m"; N = "n";
                      O = "o"; P = "p"; Q = "q"; R = "r"; S = "s"; T = "t"; U = "u";
                      V = "v"; W = "w"; X = "x"; Y = "y"; Z = "z";
                    };
                    lowerChar = if isUpper then lowerMap.${char} else char;
                  in
                    if isUpper && idx > 0
                    then "-${lowerChar}"
                    else lowerChar;
                chars = builtins.genList processIdx len;
              in builtins.concatStringsSep "" chars;

          in
            if moduleName != null && moduleName != ""
            then toKebabCase moduleName
            else null
        else null;
    in
      appNameFromRails;
}
