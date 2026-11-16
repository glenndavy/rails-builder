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
      "aarch64-linux" = "sha256-vcXZPqU3X1BWgflGfSX5NrHS6+YX1pS6C5dGhnqf+GA=";
    };
  };
  "4.1.18" = {
    npmDeps = {
      "x86_64-linux" = "sha256-CXpbZretKxTwC0+tUXimlqkNhUnfBlFBJ/iH3YUK3Bw=";
      "aarch64-linux" = "sha256-ciYGXhq4bJiM1NP0eLwdinDOiOdPU2u346tq7aMFbE4=";
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
      "aarch64-linux" = "sha256-7oGU/ACeqm9giC9Ko/1dm7FAL6svd4OFrpLZxP9FZ0Q=";
    };
  };
  "4.2.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-uObxpheJHvPzGikgndx4jN9ZnLlNFgTHtin6xoHvuaY=";
      "aarch64-linux" = "sha256-xfHnb7vOpLJ7teBiC5nTXkQMqpTlOXpZ8758A+tNZQs=";
    };
  };
  "4.2.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-yBVUj5WxsEkCV5b4vlprSS3PU43vy7GI9JVNadbk+Fc=";
      "aarch64-linux" = "sha256-tEKmelD4dko7GOq2T1viDk0ROeZ38rKvc4Q6Vi4XfB4=";
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
      "aarch64-linux" = "sha256-xT5uAsoiWYDOUpNyYFxwAVvYQUqthj9UawxOQIOeQto=";
    };
  };
  "4.0.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-rOXzUC3yfEUZtE1RsGgJS9ffIznePd4dg2/AdqDxJh0=";
      "aarch64-linux" = "sha256-3IDByqYf7ZEchl55JOhG9y9RCVvJZEf++9Z6EF34dBA=";
    };
  };
  "4.0.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-HZDIS6S1PbRpVYSPjQe3HQQ2kIROrmUL49KUdv7ynvc=";
      "aarch64-linux" = "sha256-xUYRIBaIacU99oG1KU5GD9mI31BBL/yurMIWIN4yHM0=";
    };
  };
  "4.0.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-vUU6/kq0WQgFfF6aHfZxPgrHHYwsoOGV5Wh0MqewItk=";
      "aarch64-linux" = "sha256-S0Zh7cln+PpE8QvaSbpu8oha1NynfB/75QMsKde5a0o=";
    };
  };
  "4.0.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-bYZxQoBQLCzyVOOCJj9aR1V4oGqkaRuJfoYC7wLi+eI=";
      "aarch64-linux" = "sha256-8eSWowwcSCegOyYORA5nuh5MKurkS8R6WPNlhVWImxQ=";
    };
  };
  "4.0.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-wJojckZY3ib5hLFk8PqYvzlsOQMB6Q9tors9lFcL7qg=";
      "aarch64-linux" = "sha256-sOqmzdEv6tzdslNOp6jMhuCx3KFRz1T7SQ2RgkJ26RE=";
    };
  };
  "4.0.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-q+8Pac9QAEq8ycqRyzDhJgL1yq/13PKJKgPYbob4NPk=";
      "aarch64-linux" = "sha256-J+zaF8K939o4QmycrLI4UVJDBAU7OuNCRf4lZjFkazs=";
    };
  };
  "4.0.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-AEoDb4e8ru7og7EktAwA/ScICo9J6pAyV3YvyejzRxQ=";
      "aarch64-linux" = "sha256-Ku0jXUQWEoHelWAlO/qhYbe5y//xRYn/bbToYYBDqjE=";
    };
  };
  "4.0.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-pmUgjWiS12EAnWjFwvwwMCvFQ3eda4SQ05/ka6+DFFg=";
      "aarch64-linux" = "sha256-6oPWby4SI/JL1JDA7JuYE/0QO415CQs49gClrmjHaxk=";
    };
  };
  "4.0.16" = {
    npmDeps = {
      "x86_64-linux" = "sha256-WTfk2UHmqBy2AXmiujRpaHz3xB5vTvFn4k2VkxEW8y8=";
      "aarch64-linux" = "sha256-mOL3Ulk0qIjW/jCYMly6U5rvtC7nB7Y1NqZ4f39NBW8=";
    };
  };
  "4.0.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-E2rmUsTOqVWhLWG2Uv+6Nc/2NUof4nxD51u6M6Vjf14=";
      "aarch64-linux" = "sha256-Tj8/a2+UWPu4e8py1lq8AYIhZ5jK6KqklxxA5Xv0ycM=";
    };
  };
  "4.0.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-OWyGX/LAXTF9Wf3hUhrS8g72tKlVa0s844TkORMlwLs=";
      "aarch64-linux" = "sha256-OXqIj+5scBagJSyr+uYVENa1tc09k+14vEFYgDmKfrs=";
    };
  };
  "4.0.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-B/WtNU4lQX4Yr01pFSwZXsND+y6JO9diNUrZRm2nYyU=";
      "aarch64-linux" = "sha256-lkD1gp4jm3LkFBsKYDPbqk25AFd0ZWj//CxsQm1mHWc=";
    };
  };
  "4.0.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-edGTxNa1qBdMdegQfDIY9Oc04PiVoux6/vUEqxJjuh8=";
      "aarch64-linux" = "sha256-n1jycp8odsCc5mAph0xijzTWr4rOJvAeHpMGCk56vsY=";
    };
  };
  "4.0.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-zHPpb/8cc9T7eXrfebktofltrXBKkxm8b+m9UaMZNV4=";
      "aarch64-linux" = "sha256-6TnfHFz+vxgD85EXD0jG3nrH3y7+WSgaMBpmSFrERJo=";
    };
  };
  "4.0.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-YaljFoq2DE6omghA90TrUdSTBlBcNKV/MT5rPId9Vf8=";
      "aarch64-linux" = "sha256-OmucEVVcGLzw6ywOoZ/WwrJWUpDqBDlIaZo/7l4W+X0=";
    };
  };
  "4.0.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-IhLMzVuFuore9mOpBg84ZfKsCOEb22t9qBg78//ky10=";
      "aarch64-linux" = "sha256-oBWKK9YhjgvhxDEI7jmtJjqq3omOLB9Mfh+dNspYUDc=";
    };
  };
  "4.0.8" = {
    npmDeps = {
      "x86_64-linux" = "sha256-/KR+5XK3OGH57sttB1bZr61PrT8WVwItror1fYPKihg=";
      "aarch64-linux" = "sha256-dDVXH0wnJA6fdGZaFVZIJfucrfM3kqVr0ZHetPrlMbU=";
    };
  };
  "4.0.9" = {
    npmDeps = {
      "x86_64-linux" = "sha256-nILjDf8efXx3YTPpgRV6e1dhtk/7/SmII1BUIiip2gA=";
      "aarch64-linux" = "sha256-Xrr34J9UTpLo3MqBbK3lRhHnxi6Q+G4n3HbCmRZBpTU=";
    };
  };
  "4.1.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-VYORPOjnDLDS1qtmlIyAgEE3xiActhtMcgwZvHm0vmM=";
      "aarch64-linux" = "sha256-rnvQqWryLesVlty9JZBFDZR9Q1F5wW3VCgK+gL7nLJM=";
    };
  };
  "4.1.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-lRaEc8YJtAyvprRvFX2jLKz+dVO9bm5TUdVHxGikS2E=";
      "aarch64-linux" = "sha256-W4GtAgHRtsi8uKfzWcRjedU4BcprKidLKb4KytwpiYI=";
    };
  };
  "4.1.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-iIFpJyazlSGfg4fbXg1MIg1sMgqHrC3F2wPuTTOt03w=";
      "aarch64-linux" = "sha256-tQBObsN/YiVuFaMozZtVC3FMJIknN7LC39QyAqG4Gmo=";
    };
  };
  "4.1.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-b0kusMAWia1Wmo64AypgKtBhLmwemga1vJyDyoBqFas=";
      "aarch64-linux" = "sha256-UJ3shsfQafUy42fN7EesCaNez4AdaRU/jHhGO0XNs+4=";
    };
  };
  "4.1.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-JPLm4cxcKGZ5g6CvPteF9EgWlZ8gGU9qzmUG4awX/V4=";
      "aarch64-linux" = "sha256-+tylMcd1y1Uzk76KE6bRqZ+Csb0Y8YxdXZdFTOsUypk=";
    };
  };
  "4.1.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-ADvNoEu21U+41gzGuTgtlMREsWzE4OMLNOJ5RLcUFsw=";
      "aarch64-linux" = "sha256-xyRaqb1+Zzu4/bRAS60KjI2iAsPv7bBCf4vR5km+CTk=";
    };
  };
  "4.1.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-MUVXvIL+Mh5CotTsIxPAEPNDIYYJvkE0IrXD8K+d9Mc=";
      "aarch64-linux" = "sha256-lYaULtpzd3azy6uCKPBgnda4OiFXyr7qjt8tE/FZrjU=";
    };
  };
  "4.1.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-RmqTZKmF6J+Z/GXVdVXKvIYQfeza6x1ggrE0vHaQ24w=";
      "aarch64-linux" = "sha256-cJsAUdpurFh7QYtioxfHiDicDxxoLNlHSy/oA/jydrM=";
    };
  };
  "4.1.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-FOZBZ9+HpE3fpXTHYA+vxmOF2qvMEKY/CKYAa9dqfO4=";
      "aarch64-linux" = "sha256-WrMvUdXoR9SphRXo0YU3L0jCq8D54s36kvxD8VKclIU=";
    };
  };
  "4.1.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-+2lEUdlrAPHuu1X/NAbWp4ovyXUrxwD+rAqFgHQfvcc=";
      "aarch64-linux" = "sha256-zPRQ6Rrq+siWRAAUxomKOyrtQq22JZHSw8pPRVtWhqY=";
    };
  };
  "4.1.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-HPCqn/Iv0dGAzGY2Rg6BEbEegUyvxkLW5kTpJRWYjk8=";
      "aarch64-linux" = "sha256-QXAoallf4RIsYC6gF44kFpXb/UqWg4IToE7p2zROKGQ=";
    };
  };
  "4.1.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-sByVr8C5KTXbZZf2r0vCbvQBd+CqJFA47y1/5V0YUTI=";
      "aarch64-linux" = "sha256-qmzfeIAV8XZMysB16OiPH4x4SsC4XeX1hK5efb/BAsQ=";
    };
  };
  "4.1.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-rL0131UzOpHzbZsbtvGm9vFlLbDJbAF/ehRaOKI6WIc=";
      "aarch64-linux" = "sha256-xH9j8xMGfrJrlokrJ3wxuFFa+qCrwPcaSI4gB6aXAoQ=";
    };
  };
  "4.1.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-xc6ZcYI6mETyavrCAFmOLxppZqg9NLkhlvdQGp8OrGk=";
      "aarch64-linux" = "sha256-N7qMpHIWpDhBHlCKFEzSPP9XT/NdktDvE/RW9M0Z5oU=";
    };
  };
  "4.1.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Fr5H2JOVnoOnj/AYBEHq7mXDxHVnA7JI5o+os659dIc=";
      "aarch64-linux" = "sha256-COBiZOWvpX82KGg81KXgiY5j3IJhk8ilPp9WW+e/TDk=";
    };
  };
  "4.1.8" = {
    npmDeps = {
      "x86_64-linux" = "sha256-5g6nB526K1VkzHGmPifxFbzk08v7W73ZbB4DG0eXOUs=";
      "aarch64-linux" = "sha256-oD2cAKighl+bctWaIX3SHdrxEGJ8hv8uFZVOc2tDDNI=";
    };
  };
  "4.1.9" = {
    npmDeps = {
      "x86_64-linux" = "sha256-KFdh5mt7xJd89RRVBtx7hSjSXFnxySEPwI1cKLOpgW4=";
      "aarch64-linux" = "sha256-ni6Cu/Am16SgfqFq3skA6aBOlpZU+B4unjZhHjrkMRE=";
    };
  };
  "4.2.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-2l3AXvDsevZ3Zcq3+80yl5xlqQCxLOvYjxoObtZ3Mmo=";
      "aarch64-linux" = "sha256-5yg0nVt27Cu7KFuIMnVsRkZU9/Z0uafuVRADKUs37bc=";
    };
  };
  "4.2.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-FM84hnlWt0t1ZP+V94XRTQ3u+Q+qiQoKTUglfBLPh3A=";
      "aarch64-linux" = "sha256-qFtCJod/yRq6DrwfdZLwWCb/2cOwBZ32sWnAI0337d4=";
    };
  };
  "4.3.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-i5K8cJGTOeEzwaj0TXtCOIKdEXLGXUhBXkn8wSKRwpU=";
      "aarch64-linux" = "sha256-FtHWDYenfFpM71Ef0tU2YPKToAz0AEmkPhZ+8uJaxCM=";
    };
  };
  "4.3.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-uSXvdguHq6zA8NY82zgi1shF8455Bq1Tax0f3xW+hK4=";
      "aarch64-linux" = "sha256-80ksqeT1NrPHMjbytf0GhaZltfBvm4asEi/VvKZDCv4=";
    };
  };
  "4.3.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-UrR3pJSUNTdwTB6fi4rpzn/tOVw6Ut5q+Zw739iz7TY=";
      "aarch64-linux" = "sha256-krRUubPuA1Msrwq8yHsP/WAklG96hADdeRSgINZZiKc=";
    };
  };
  "4.3.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-IEGw63BIWLIOJ478QSHLg4zNOKnQa7MQRz3CUMduiqQ=";
      "aarch64-linux" = "sha256-KTQw0gDF0yUW2Oc5kDpKEnY5Sx6cvhNioZlQl8dHTcc=";
    };
  };
  "4.3.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-DEBUPPlAHLvjReghW9b+YabA4Ea0tduNjy8MKAPkbCg=";
      "aarch64-linux" = "sha256-ujt0khw1LHl4OOMimI4Bp7PERhqeixdVi+BJnhhu154=";
    };
  };
}
