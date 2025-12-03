# Version detection functions for Ruby applications
# These functions can be imported and used by other flakes
{
  # Detect Ruby version from .ruby-version file or Gemfile
  # Usage: detectRubyVersion { src = ./.; }
  # Returns: String like "3.2.0"
  detectRubyVersion = {src}: let
    rubyVersionFile = src + "/.ruby-version";
    gemfile = src + "/Gemfile";
    parseVersion = version: let
      trimmed = builtins.replaceStrings ["\n" "\r" " "] ["" "" ""] version;
      cleaned = builtins.replaceStrings ["ruby-" "ruby"] ["" ""] trimmed;
    in
      builtins.match "^([0-9]+\\.[0-9]+\\.[0-9]+)$" cleaned;
    fromRubyVersion =
      if builtins.pathExists rubyVersionFile
      then let
        version = builtins.readFile rubyVersionFile;
      in
        if parseVersion version != null
        then builtins.head (parseVersion version)
        else throw "Error: Invalid Ruby version in .ruby-version: ${version}"
      else throw "Error: No .ruby-version found in APP_ROOT";
    fromGemfile =
      if builtins.pathExists gemfile
      then let
        content = builtins.readFile gemfile;
        match = builtins.match ".*ruby ['\"]([0-9]+\\.[0-9]+\\.[0-9]+)['\"].*" content;
      in
        if match != null
        then builtins.head match
        else fromRubyVersion
      else fromRubyVersion;
  in
    fromGemfile;

  # Detect Bundler version from Gemfile.lock
  # Usage: detectBundlerVersion { src = ./.; }
  # Returns: String like "2.4.0"
  detectBundlerVersion = {src}: let
    gemfileLock = src + "/Gemfile.lock";
    parseVersion = version: builtins.match "([0-9]+\\.[0-9]+\\.[0-9]+)" version;
    fromGemfileLock =
      if builtins.pathExists gemfileLock
      then let
        content = builtins.readFile gemfileLock;
        match = builtins.match ".*BUNDLED WITH\n   ([0-9.]+).*" content;
      in
        if match != null && parseVersion (builtins.head match) != null
        then builtins.head match
        else throw "Error: Invalid or missing Bundler version in Gemfile.lock"
      else throw "Error: No Gemfile.lock found";
  in
    fromGemfileLock;

  # Detect Node.js version from .nvmrc, .node-version, or package.json engines field
  # Usage: detectNodeVersion { src = ./.; }
  # Returns: String like "20" (major version) or null if not specified
  detectNodeVersion = {src}: let
    nvmrcFile = src + "/.nvmrc";
    nodeVersionFile = src + "/.node-version";
    packageJson = src + "/package.json";

    parseVersion = version: let
      trimmed = builtins.replaceStrings ["\n" "\r" " " "v" "node"] ["" "" "" "" ""] version;
    in
      # Match exact version (e.g., "20.0.0") and extract major version
      if builtins.match "^([0-9]+)\\.[0-9]+\\.[0-9]+$" trimmed != null
      then builtins.head (builtins.match "^([0-9]+)\\.[0-9]+\\.[0-9]+$" trimmed)
      # Match major version only (e.g., "20")
      else if builtins.match "^([0-9]+)$" trimmed != null
      then builtins.head (builtins.match "^([0-9]+)$" trimmed)
      # Match range specification (e.g., ">=18.0.0" or "^20.0.0")
      else if builtins.match "^[><=^~]*([0-9]+).*" trimmed != null
      then builtins.head (builtins.match "^[><=^~]*([0-9]+).*" trimmed)
      else null;

    fromNvmrc =
      if builtins.pathExists nvmrcFile
      then parseVersion (builtins.readFile nvmrcFile)
      else null;

    fromNodeVersion =
      if builtins.pathExists nodeVersionFile
      then parseVersion (builtins.readFile nodeVersionFile)
      else null;

    fromPackageJson =
      if builtins.pathExists packageJson
      then let
        content = builtins.readFile packageJson;
        # Try to extract node version from engines.node field
        # This is a simple regex match - not full JSON parsing
        match = builtins.match ".*\"node\"[[:space:]]*:[[:space:]]*\"([^\"]+)\".*" content;
      in
        if match != null
        then parseVersion (builtins.head match)
        else null
      else null;
  in
    # Priority: .nvmrc > .node-version > package.json engines.node
    if fromNvmrc != null then fromNvmrc
    else if fromNodeVersion != null then fromNodeVersion
    else fromPackageJson;
}
