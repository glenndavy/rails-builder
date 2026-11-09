# Precomputed SHA256 hashes for tailwindcss npm dependencies
# Format: version.npmDeps.${system} = "hash"
#
# The hash is for the full node_modules directory created by `bun install @tailwindcss/cli@VERSION`
# Hashes are architecture-specific due to platform-specific npm packages.
# To add a new version, set npmDeps = {} and build - nix will show the correct hash.
#
{
  "4.1.16" = {
    npmDeps = {
      "x86_64-linux" = "sha256-EDlqspPlthtf6oXpu3LC5HbgxC1H7EMOmTFX+o7/mBQ=";
    };
  };
  "4.1.18" = {
    npmDeps = {
      "x86_64-linux" = "sha256-CXpbZretKxTwC0+tUXimlqkNhUnfBlFBJ/iH3YUK3Bw=";
    };
  };
  "4.2.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-adVf19XNYcvWn7d39RnIfKFdFMZ4xUAVwhrkoCjTiUg=";
      # Re-pinned TWICE on consecutive days (2026-08-18 x2): unfrozen
      # `bun install` output drifted from V4Gu… → GbW0… → jZTjh… in
      # under 24h. This cadence means the FOD may even be nondeter-
      # ministic per-run, not merely tracking upstream movement. Do
      # NOT keep re-pinning: the durable fix (vendored bun.lock +
      # --frozen-lockfile) is mandatory — see rails-builder issue
      # tracked as rx-stack task #54. If THIS pin fails again, stop
      # and implement the freeze before any further builds.
      "aarch64-linux" = "sha256-jZTjhAG6rOzSgo0h7lmND5tQIbIGI5JvC4n3/XIRdis=";
    };
  };
  "4.2.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-uObxpheJHvPzGikgndx4jN9ZnLlNFgTHtin6xoHvuaY=";
    };
  };
  "4.2.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-yBVUj5WxsEkCV5b4vlprSS3PU43vy7GI9JVNadbk+Fc=";
    };
  };
  "4.3.0" = {
    npmDeps = {
      # NOTE: this hash flip-flops between two values depending on which
      # bun builds the FOD (lockfile is frozen; bun's node_modules layout
      # differs across bun versions from different nixpkgs pins).
      #   zovIIqJ… = bun from rails-builder/nixpkgs 2026-05-15 (botman-box
      #              containers after `nix flake update` — production).
      #   +n6zOE…  = bun from an older nixpkgs (local dev builds).
      # Pinned to the production value. Durable fix: pin bun itself in
      # make-tailwindcss.nix (see 4.2.2 note / rx-stack task #54).
      "x86_64-linux" = "sha256-xJD/NLZu1ZJ6EffNm4gig9aB+LWuRtgg18X1N4cbZTI=";
      "aarch64-linux" = "sha256-CcWOsgK1M5Nkxwqnzgbz3uGOmcUpyYYlM7TBDM0EdJ8=";
    };
  };
  "4.0.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-ZtmvsyONrPOeKZt7/H1308Z7C0Gy4P19g342FMhuv68=";
    };
  };
  "4.0.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-RaW+BefFAQ/ExIW2/8n1rcpPo5/cOuRm+COZ16Qt2fs=";
    };
  };
  "4.0.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-yTvdwiqZ5s/JB40aAm5ViExoOpEKlIx4LI2JI4JXmw8=";
    };
  };
  "4.0.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-vaqt4f4qfQZA9klyeqkZPkBsZGjJzbkbI6uIuxnWwyE=";
    };
  };
  "4.0.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-OUCu/WUFKAkhOnmruC/027JpdTkdiq03GMKP4K82X/A=";
    };
  };
  "4.0.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-0IQWZrMKRzzF05y6mt83b1qXygltIVlC/m/3MduJT8E=";
    };
  };
  "4.0.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-kfO3DEatULGFZZhuD9Zb7wFGMkroKbOA9xJnL5rT18I=";
    };
  };
  "4.0.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-UcI7wGIzK99DCuD26ieOcwfyQ3l0bg0ZnGdMyXsf1yI=";
    };
  };
  "4.0.16" = {
    npmDeps = {
      "x86_64-linux" = "sha256-SMMHrd32qksVCoPmw2uY9J+xJ3CEXIMtqGv6kmbSPbs=";
    };
  };
  "4.0.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Jlxx8Hyk+dJ8og+WnLn4cw/Zo+agGbYVhXm/9HB3/bo=";
    };
  };
  "4.0.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-8tjTo1qKI1dSy9MSIEL04k6L31j4ZoUrWA4zK3nDVdQ=";
    };
  };
  "4.0.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-OhzeHeXjDunHBWdMJBydsODiDDEfRTLV290ViUKwPnM=";
    };
  };
  "4.0.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-EH55IJ2RYJ3G6WcqB3LFOJvMcBEXx2LdUyt9mPc6DE8=";
    };
  };
  "4.0.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-LGdDP+6Tgry/DKWXiDZE6j5YM3nlOr1PaSPiiR8L6j0=";
    };
  };
  "4.0.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-je0fJV+rHnvR29cyTBCIeqJ7aTyb3lavmhWluWRRdmI=";
    };
  };
  "4.0.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-iiZFs3UwQeg9+S03YRa5XRb4zu9o6v6KfewV1ZKsI5Y=";
    };
  };
  "4.0.8" = {
    npmDeps = {
      "x86_64-linux" = "sha256-dL0yUhUQ+dwna+bFc8kUh09Ol/BqS6uIRZaXpH5NA8g=";
    };
  };
  "4.0.9" = {
    npmDeps = {
      "x86_64-linux" = "sha256-gFP6STgXLx40asbBdCTJbvm5smZ67xLVg0n1HG5GusM=";
    };
  };
  "4.1.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-arRmGxdPr5uXOXP0/OVMZhOGxPXVEcGvMkZFmf15VTk=";
    };
  };
  "4.1.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Om28ogz4yE2iu7uoBUi1uVLk8aStRFEfWgBEjzvhm8g=";
    };
  };
  "4.1.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-QQCDNKBhP6UrKoDHxasHA7IcGBwf+xLBXxodiEw2txw=";
    };
  };
  "4.1.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-ROIMc2N8OURgZC9bilgeYgBxlBz7CSzutUCMjhAy52Y=";
    };
  };
  "4.1.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-TUjGk58e2l+ZZFYw91d641oo0c3ztmg1nm8rS5xSmmQ=";
    };
  };
  "4.1.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Pxfpi05JHLoQshA3SJ2uEfvGxSUrm/Xc3Y3pSh2RNF4=";
    };
  };
  "4.1.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-j0HY3k0RDL46/Lv2QBnHV7pDTqsSvr9Vtiky9eF3gXo=";
    };
  };
  "4.1.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-I97V12b0OLRx1X7EUCDSQRC46d8b1Iar6yRfDqHoytQ=";
    };
  };
  "4.1.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-13CVADNEpRHMeOcZxLOZ7bXonfcHVAjElCLItCdlScE=";
    };
  };
  "4.1.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-I9+GRwxLoLaRBDV7pMZSBioEiW60/U1YOlcwoHHGT9Q=";
    };
  };
  "4.1.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-b9AxnC5YLKwo/lHiWHWaYwan20VG+dbrSinbaBHduQA=";
    };
  };
  "4.1.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-ju7nmnNxd9DGiuuDQ4UauVb27oIiMYmdZ2J+IXQTguk=";
    };
  };
  "4.1.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-LE590+AblCl5Wtw8cc1Ai+BcgBXkXeBRzuRJCPlQ2og=";
    };
  };
  "4.1.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-86C1Z4rlnExW55EwO92qcITIcu3HIigialJUB+6m63k=";
    };
  };
  "4.1.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-0K/4CPTbuW62Udn8iRyiaDU0u7/Jc2SIImyprV/v7iU=";
    };
  };
  "4.1.8" = {
    npmDeps = {
      "x86_64-linux" = "sha256-5g6nB526K1VkzHGmPifxFbzk08v7W73ZbB4DG0eXOUs=";
    };
  };
  "4.1.9" = {
    npmDeps = {
      "x86_64-linux" = "sha256-5qn5LzyB1dwnFuti/9LywHPfZmhVBcEfBZ9OmhXjx2Q=";
    };
  };
  "4.2.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-9tPaN7ghyieFfEInUqhwVuogGsylQ2dhR1m9rDTHgQ0=";
    };
  };
  "4.2.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-hKdZvLvApdVOiTqHIsVVPKSbuF/qrp+CmSBgPklvRr0=";
    };
  };
}
