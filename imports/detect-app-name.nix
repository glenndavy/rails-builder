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
            # Match "module SomeName" at the start of a line
            # This regex finds the module name
            lines = builtins.filter
              (line: builtins.match "^module [A-Z].*" line != null)
              (builtins.split "\n" content);
            # Extract first matching line
            moduleLine = if builtins.length lines > 0
              then builtins.head (builtins.filter builtins.isString lines)
              else null;
            # Extract module name from "module FooBar" -> "FooBar"
            moduleName =
              if moduleLine != null
              then
                let
                  # Remove "module " prefix
                  withoutPrefix = builtins.substring 7 (builtins.stringLength moduleLine - 7) moduleLine;
                  # Trim any trailing whitespace or comments
                  trimmed = builtins.head (builtins.split " " withoutPrefix);
                in trimmed
              else null;
            # Convert CamelCase to kebab-case
            # OpsCore -> ops-core, MyRailsApp -> my-rails-app
            toKebabCase = str:
              let
                chars = builtins.stringToCharacters str;
                processChar = i: char:
                  let
                    isUpper = builtins.match "[A-Z]" char != null;
                    lower = builtins.elemAt (builtins.split "[A-Z]" char) 0;
                    lowerChar =
                      if isUpper
                      then builtins.elemAt ["a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z"]
                        (builtins.elemAt [0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25]
                          (builtins.head (builtins.filter (x: x != null)
                            (builtins.genList (n: if char == builtins.elemAt ["A" "B" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L" "M" "N" "O" "P" "Q" "R" "S" "T" "U" "V" "W" "X" "Y" "Z"] n then n else null) 26))))
                      else char;
                  in
                    if isUpper && i > 0
                    then "-${lowerChar}"
                    else lowerChar;
                processed = builtins.genList (i: processChar i (builtins.elemAt chars i)) (builtins.length chars);
              in builtins.concatStringsSep "" processed;
          in
            if moduleName != null
            then toKebabCase moduleName
            else null
        else null;
    in
      appNameFromRails;
}
