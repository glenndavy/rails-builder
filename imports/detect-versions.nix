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

  # Detect which Node.js the app asks for, in enough detail to pick a package.
  # (detectNodeVersion above only returns a major and treats ">=18" as "18".)
  # Usage: detectNodeVersionSpec { src = ./.; }
  # Returns: {
  #   version  — "14.21.3" (exact pin), "16" / "16.20" (latest in that line),
  #              or null when nothing pins a line
  #   atLeast  — integer major for a bare ">=N" requirement, else null
  #   source   — file the request came from, or null
  #   raw      — the unparsed request string, or null
  # }
  # Priority: .nvmrc > .node-version > .tool-versions > package.json
  # volta.node > package.json engines.node
  detectNodeVersionSpec = {src}: let
    ltsCodenames = {
      dubnium = "10"; erbium = "12"; fermium = "14"; gallium = "16";
      hydrogen = "18"; iron = "20"; jod = "22"; krypton = "24";
    };
    firstMatch = regex: s: let m = builtins.match regex s; in if m == null then null else builtins.head m;

    parse = raw: let
      trimmed = builtins.replaceStrings ["\n" "\r" " " "\t"] ["" "" "" ""] raw;
      s = let m = builtins.match "^[vV=](.*)$" trimmed; in if m == null then trimmed else builtins.head m;
      lts = firstMatch "^lts/([a-z]+)$" s;
      exact = firstMatch "^([0-9]+\\.[0-9]+\\.[0-9]+)$" s;
      majorOnly = firstMatch "^([0-9]+)(\\.[xX*])?(\\.[xX*])?$" s;
      majorMinor = firstMatch "^([0-9]+\\.[0-9]+)(\\.[xX*])?$" s;
      caret = firstMatch "^\\^([0-9]+)(\\..*)?$" s;
      tildeMinor = firstMatch "^~([0-9]+\\.[0-9]+)(\\..*)?$" s;
      tildeMajor = firstMatch "^~([0-9]+)$" s;
      atLeast = firstMatch "^>=([0-9]+)(\\.[0-9xX*.]+)?$" s;
      version =
        if lts != null then ltsCodenames.${lts} or null
        else if exact != null then exact
        else if majorOnly != null then majorOnly
        else if majorMinor != null then majorMinor
        else if caret != null then caret
        else if tildeMinor != null then tildeMinor
        else tildeMajor;
    in {
      inherit version;
      atLeast = if version == null && atLeast != null then builtins.fromJSON atLeast else null;
    };

    fromFile = name: let f = src + "/${name}"; in
      if builtins.pathExists f then { raw = builtins.readFile f; source = name; } else null;

    fromRegex = name: label: regex: let f = src + "/${name}"; in
      if builtins.pathExists f
      then let m = builtins.match regex (builtins.readFile f); in
        if m == null then null else { raw = builtins.elemAt m (builtins.length m - 1); source = label; }
      else null;

    candidates = builtins.filter (c: c != null) [
      (fromFile ".nvmrc")
      (fromFile ".node-version")
      (fromRegex ".tool-versions" ".tool-versions" "(.*\n)?nodejs[ \t]+([^ \t\n]+).*")
      (fromRegex "package.json" "package.json volta.node"
        ".*\"volta\"[[:space:]]*:[[:space:]]*\\{[^}]*\"node\"[[:space:]]*:[[:space:]]*\"([^\"]+)\".*")
      (fromRegex "package.json" "package.json engines.node"
        ".*\"engines\"[[:space:]]*:[[:space:]]*\\{[^}]*\"node\"[[:space:]]*:[[:space:]]*\"([^\"]+)\".*")
    ];
  in
    if candidates == []
    then { version = null; atLeast = null; source = null; raw = null; }
    else let c = builtins.head candidates; in
      (parse c.raw) // {
        inherit (c) source;
        raw = builtins.replaceStrings ["\n" "\r"] ["" ""] c.raw;
      };

  # Detect Tailwind CSS version from Gemfile.lock (via tailwindcss-ruby gem)
  # Usage: detectTailwindVersion { src = ./.; }
  # Returns: String like "4.1.16" or null if not found
  detectTailwindVersion = {src}: let
    gemfileLock = src + "/Gemfile.lock";
    fromGemfileLock =
      if builtins.pathExists gemfileLock
      then let
        content = builtins.readFile gemfileLock;
        # Match tailwindcss-ruby (version) - the generic ruby platform entry
        match = builtins.match ".*tailwindcss-ruby \\(([0-9]+\\.[0-9]+\\.[0-9]+)\\).*" content;
      in
        if match != null
        then builtins.head match
        else null
      else null;
  in
    fromGemfileLock;
}
