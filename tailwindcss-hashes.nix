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
      "x86_64-linux" = "sha256-3JFXbOwOikY2wtUX2jTvH1PYENOK7erPUKGRQu78IKw=";
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
      "x86_64-linux" = "sha256-rOXzUC3yfEUZtE1RsGgJS9ffIznePd4dg2/AdqDxJh0=";
    };
  };
  "4.0.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-HZDIS6S1PbRpVYSPjQe3HQQ2kIROrmUL49KUdv7ynvc=";
    };
  };
  "4.0.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-vUU6/kq0WQgFfF6aHfZxPgrHHYwsoOGV5Wh0MqewItk=";
    };
  };
  "4.0.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-bYZxQoBQLCzyVOOCJj9aR1V4oGqkaRuJfoYC7wLi+eI=";
    };
  };
  "4.0.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-wJojckZY3ib5hLFk8PqYvzlsOQMB6Q9tors9lFcL7qg=";
    };
  };
  "4.0.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-q+8Pac9QAEq8ycqRyzDhJgL1yq/13PKJKgPYbob4NPk=";
    };
  };
  "4.0.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-AEoDb4e8ru7og7EktAwA/ScICo9J6pAyV3YvyejzRxQ=";
    };
  };
  "4.0.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-pmUgjWiS12EAnWjFwvwwMCvFQ3eda4SQ05/ka6+DFFg=";
    };
  };
  "4.0.16" = {
    npmDeps = {
      "x86_64-linux" = "sha256-WTfk2UHmqBy2AXmiujRpaHz3xB5vTvFn4k2VkxEW8y8=";
    };
  };
  "4.0.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-E2rmUsTOqVWhLWG2Uv+6Nc/2NUof4nxD51u6M6Vjf14=";
    };
  };
  "4.0.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-OWyGX/LAXTF9Wf3hUhrS8g72tKlVa0s844TkORMlwLs=";
    };
  };
  "4.0.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-B/WtNU4lQX4Yr01pFSwZXsND+y6JO9diNUrZRm2nYyU=";
    };
  };
  "4.0.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-edGTxNa1qBdMdegQfDIY9Oc04PiVoux6/vUEqxJjuh8=";
    };
  };
  "4.0.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-zHPpb/8cc9T7eXrfebktofltrXBKkxm8b+m9UaMZNV4=";
    };
  };
  "4.0.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-YaljFoq2DE6omghA90TrUdSTBlBcNKV/MT5rPId9Vf8=";
    };
  };
  "4.0.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-IhLMzVuFuore9mOpBg84ZfKsCOEb22t9qBg78//ky10=";
    };
  };
  "4.0.8" = {
    npmDeps = {
      "x86_64-linux" = "sha256-/KR+5XK3OGH57sttB1bZr61PrT8WVwItror1fYPKihg=";
    };
  };
  "4.0.9" = {
    npmDeps = {
      "x86_64-linux" = "sha256-nILjDf8efXx3YTPpgRV6e1dhtk/7/SmII1BUIiip2gA=";
    };
  };
  "4.1.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-VYORPOjnDLDS1qtmlIyAgEE3xiActhtMcgwZvHm0vmM=";
    };
  };
  "4.1.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-lRaEc8YJtAyvprRvFX2jLKz+dVO9bm5TUdVHxGikS2E=";
    };
  };
  "4.1.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-iIFpJyazlSGfg4fbXg1MIg1sMgqHrC3F2wPuTTOt03w=";
    };
  };
  "4.1.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-b0kusMAWia1Wmo64AypgKtBhLmwemga1vJyDyoBqFas=";
    };
  };
  "4.1.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-JPLm4cxcKGZ5g6CvPteF9EgWlZ8gGU9qzmUG4awX/V4=";
    };
  };
  "4.1.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-ADvNoEu21U+41gzGuTgtlMREsWzE4OMLNOJ5RLcUFsw=";
    };
  };
  "4.1.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-MUVXvIL+Mh5CotTsIxPAEPNDIYYJvkE0IrXD8K+d9Mc=";
    };
  };
  "4.1.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-RmqTZKmF6J+Z/GXVdVXKvIYQfeza6x1ggrE0vHaQ24w=";
    };
  };
  "4.1.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-FOZBZ9+HpE3fpXTHYA+vxmOF2qvMEKY/CKYAa9dqfO4=";
    };
  };
  "4.1.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-+2lEUdlrAPHuu1X/NAbWp4ovyXUrxwD+rAqFgHQfvcc=";
    };
  };
  "4.1.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-HPCqn/Iv0dGAzGY2Rg6BEbEegUyvxkLW5kTpJRWYjk8=";
    };
  };
  "4.1.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-sByVr8C5KTXbZZf2r0vCbvQBd+CqJFA47y1/5V0YUTI=";
    };
  };
  "4.1.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-rL0131UzOpHzbZsbtvGm9vFlLbDJbAF/ehRaOKI6WIc=";
    };
  };
  "4.1.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-xc6ZcYI6mETyavrCAFmOLxppZqg9NLkhlvdQGp8OrGk=";
    };
  };
  "4.1.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Fr5H2JOVnoOnj/AYBEHq7mXDxHVnA7JI5o+os659dIc=";
    };
  };
  "4.1.8" = {
    npmDeps = {
      "x86_64-linux" = "sha256-5g6nB526K1VkzHGmPifxFbzk08v7W73ZbB4DG0eXOUs=";
    };
  };
  "4.1.9" = {
    npmDeps = {
      "x86_64-linux" = "sha256-KFdh5mt7xJd89RRVBtx7hSjSXFnxySEPwI1cKLOpgW4=";
    };
  };
  "4.2.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-2l3AXvDsevZ3Zcq3+80yl5xlqQCxLOvYjxoObtZ3Mmo=";
    };
  };
  "4.2.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-FM84hnlWt0t1ZP+V94XRTQ3u+Q+qiQoKTUglfBLPh3A=";
    };
  };
  "4.3.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-i5K8cJGTOeEzwaj0TXtCOIKdEXLGXUhBXkn8wSKRwpU=";
      "aarch64-linux" = "sha256-Obb9n8JxHXvTcIhdTmA5p+V136lQASpRGINZLV1NhRw=";
    };
  };
  "4.3.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-uSXvdguHq6zA8NY82zgi1shF8455Bq1Tax0f3xW+hK4=";
      "aarch64-linux" = "sha256-YmeG360VWOwS4Rt5qv4IqWOg1uqiM8oJSHAWkdSlHiY=";
    };
  };
  "4.3.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-UrR3pJSUNTdwTB6fi4rpzn/tOVw6Ut5q+Zw739iz7TY=";
      "aarch64-linux" = "sha256-58GmJlERbWN7OjAqkvwJVYhDMAnWlLc8+PRStkmz16c=";
    };
  };
  "4.3.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-IEGw63BIWLIOJ478QSHLg4zNOKnQa7MQRz3CUMduiqQ=";
      "aarch64-linux" = "sha256-dcYYXt3z1yQnuWXEDJukBnMLFg0weUZsWdsX0yTcKS8=";
    };
  };
  "4.3.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-DEBUPPlAHLvjReghW9b+YabA4Ea0tduNjy8MKAPkbCg=";
      "aarch64-linux" = "sha256-pAF6yivbdRxGV/gQDMiJMwoXJVfqaY9PHIqxjkrsLuY=";
    };
  };
}
