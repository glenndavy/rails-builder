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
      "aarch64-linux" = "sha256-qOXBn2kIaIKGn1oT8BdeiMetbwosK/0gKD24tvcDlkE=";
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
      "x86_64-linux" = "sha256-ZtmvsyONrPOeKZt7/H1308Z7C0Gy4P19g342FMhuv68=";
      "aarch64-linux" = "sha256-Acagsm9Buis+mY8trcZ/LQqTUBYf+ID3fyr4RiIEfgI=";
    };
  };
  "4.0.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-RaW+BefFAQ/ExIW2/8n1rcpPo5/cOuRm+COZ16Qt2fs=";
      "aarch64-linux" = "sha256-mt9JGAIqiGxnd8rnG86HS8JGuYUyl8mMh53ApupLK5U=";
    };
  };
  "4.0.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-yTvdwiqZ5s/JB40aAm5ViExoOpEKlIx4LI2JI4JXmw8=";
      "aarch64-linux" = "sha256-9rZIoJMmTeEBgw8bpJN5QAdRkC5dr1p9lVw3S422c14=";
    };
  };
  "4.0.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-vaqt4f4qfQZA9klyeqkZPkBsZGjJzbkbI6uIuxnWwyE=";
      "aarch64-linux" = "sha256-orXc5PAslrQ2exGpFVzZ05SmzKIsSKV5tR41/Lqhnrc=";
    };
  };
  "4.0.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-OUCu/WUFKAkhOnmruC/027JpdTkdiq03GMKP4K82X/A=";
      "aarch64-linux" = "sha256-ZupZhEWg1bmgYbvbLLfyetWac8iyZPQbNcqujmGbs74=";
    };
  };
  "4.0.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-0IQWZrMKRzzF05y6mt83b1qXygltIVlC/m/3MduJT8E=";
      "aarch64-linux" = "sha256-Tx2Vdx2zAuRv3tUAXhUchpW6OZubTtO+EfUt2GcBNO4=";
    };
  };
  "4.0.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-kfO3DEatULGFZZhuD9Zb7wFGMkroKbOA9xJnL5rT18I=";
      "aarch64-linux" = "sha256-CMv6rc91PHcjBRrEEbpgEjSiZLqDx1Q7u4q9YQZcLYg=";
    };
  };
  "4.0.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-UcI7wGIzK99DCuD26ieOcwfyQ3l0bg0ZnGdMyXsf1yI=";
      "aarch64-linux" = "sha256-/LV6iCgb/7Q3AOoSqzUrcH+XcJYXFRSqTVmhvhpajII=";
    };
  };
  "4.0.16" = {
    npmDeps = {
      "x86_64-linux" = "sha256-SMMHrd32qksVCoPmw2uY9J+xJ3CEXIMtqGv6kmbSPbs=";
      "aarch64-linux" = "sha256-1mWCQ5+SVq8Okog2qw1B4b+B0x+NrzCNuMvUwx9Xdgo=";
    };
  };
  "4.0.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Jlxx8Hyk+dJ8og+WnLn4cw/Zo+agGbYVhXm/9HB3/bo=";
      "aarch64-linux" = "sha256-H3rWYX5i23ZwJXf99ANLveiiZ8+sMfjeIbjsoKUBA4w=";
    };
  };
  "4.0.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-8tjTo1qKI1dSy9MSIEL04k6L31j4ZoUrWA4zK3nDVdQ=";
      "aarch64-linux" = "sha256-GQsYZmfSmv/bXj1cvNXa1qSEP71K5scRu10A98V9BUE=";
    };
  };
  "4.0.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-OhzeHeXjDunHBWdMJBydsODiDDEfRTLV290ViUKwPnM=";
      "aarch64-linux" = "sha256-G0bOafCIB61RC7irNY4jBPHXq5wB8V1Cghn/GLhVPxg=";
    };
  };
  "4.0.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-EH55IJ2RYJ3G6WcqB3LFOJvMcBEXx2LdUyt9mPc6DE8=";
      "aarch64-linux" = "sha256-I5Jo/a/VMB7Ad1TKwdHg3UJtYGNZH4DvxTyd4A+++kU=";
    };
  };
  "4.0.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-LGdDP+6Tgry/DKWXiDZE6j5YM3nlOr1PaSPiiR8L6j0=";
      "aarch64-linux" = "sha256-JIt3XRM1QK8s+Ja/3g9TAT66waA2aRcJ+OhOUvkJboc=";
    };
  };
  "4.0.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-je0fJV+rHnvR29cyTBCIeqJ7aTyb3lavmhWluWRRdmI=";
      "aarch64-linux" = "sha256-u5P85THyCdWak6kSykS8JYbjHEpePSjz1n4TqYm20vM=";
    };
  };
  "4.0.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-iiZFs3UwQeg9+S03YRa5XRb4zu9o6v6KfewV1ZKsI5Y=";
      "aarch64-linux" = "sha256-8rBdn6werDlrcSXxQon8z+33UwWDlIMh46mc4pQ1Y+c=";
    };
  };
  "4.0.8" = {
    npmDeps = {
      "x86_64-linux" = "sha256-dL0yUhUQ+dwna+bFc8kUh09Ol/BqS6uIRZaXpH5NA8g=";
      "aarch64-linux" = "sha256-9TOXVO0OfXYAQBFY50s8mXZ8AKPlSrodZ83SAoERy7E=";
    };
  };
  "4.0.9" = {
    npmDeps = {
      "x86_64-linux" = "sha256-gFP6STgXLx40asbBdCTJbvm5smZ67xLVg0n1HG5GusM=";
      "aarch64-linux" = "sha256-6duaxVVGMCYp08qCQUFmwf3shGWje07igJeffTlnoRA=";
    };
  };
  "4.1.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-arRmGxdPr5uXOXP0/OVMZhOGxPXVEcGvMkZFmf15VTk=";
      "aarch64-linux" = "sha256-ccM2/auxVttv6isjwlQlWcmRmFDPfADTHwMvfYXl8k4=";
    };
  };
  "4.1.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Om28ogz4yE2iu7uoBUi1uVLk8aStRFEfWgBEjzvhm8g=";
      "aarch64-linux" = "sha256-k8Vh2SJx/+NzBBilxZz3MAyHCyaJO/S7LOftoleDfTg=";
    };
  };
  "4.1.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-QQCDNKBhP6UrKoDHxasHA7IcGBwf+xLBXxodiEw2txw=";
      "aarch64-linux" = "sha256-zNdrZBWEGNZmKnUcHBCcOczQp9IxoMPqf95t2iyrilM=";
    };
  };
  "4.1.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-ROIMc2N8OURgZC9bilgeYgBxlBz7CSzutUCMjhAy52Y=";
      "aarch64-linux" = "sha256-aix/eSdaqwrnA7xmV96nBgw+KotJXumRARw76qRzL34=";
    };
  };
  "4.1.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-TUjGk58e2l+ZZFYw91d641oo0c3ztmg1nm8rS5xSmmQ=";
      "aarch64-linux" = "sha256-+IF7WB8ePt7QqCS0cnF2nreBB/7DvzYovFh/XhDVdQU=";
    };
  };
  "4.1.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Pxfpi05JHLoQshA3SJ2uEfvGxSUrm/Xc3Y3pSh2RNF4=";
      "aarch64-linux" = "sha256-U2GIFxUpbERVMmYJPXypYxZrQk2ONurkWDn4oQ8usoA=";
    };
  };
  "4.1.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-j0HY3k0RDL46/Lv2QBnHV7pDTqsSvr9Vtiky9eF3gXo=";
      "aarch64-linux" = "sha256-r2SyEdEtfDy04N5qEo0T6/4/iGvqVPJ9tL7fOF1l7p4=";
    };
  };
  "4.1.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-I97V12b0OLRx1X7EUCDSQRC46d8b1Iar6yRfDqHoytQ=";
      "aarch64-linux" = "sha256-LAVnzxVOsb/zhmH3kCjOn5+onhfP9KdBrmWAQbwRKNE=";
    };
  };
  "4.1.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-13CVADNEpRHMeOcZxLOZ7bXonfcHVAjElCLItCdlScE=";
      "aarch64-linux" = "sha256-rN8xSRITN+w1hDteDEZUD2SXdg+C2DSocvqa/QycF0A=";
    };
  };
  "4.1.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-I9+GRwxLoLaRBDV7pMZSBioEiW60/U1YOlcwoHHGT9Q=";
      "aarch64-linux" = "sha256-ZGDx0UTzAHtadygS5tPbR/hv2TVIUw9yEFPtzV0+qeE=";
    };
  };
  "4.1.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-b9AxnC5YLKwo/lHiWHWaYwan20VG+dbrSinbaBHduQA=";
      "aarch64-linux" = "sha256-0D9l9CA5AO+AyZMCT2GTaeGFx/xE4o7jIH7iRz8kh9I=";
    };
  };
  "4.1.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-ju7nmnNxd9DGiuuDQ4UauVb27oIiMYmdZ2J+IXQTguk=";
      "aarch64-linux" = "sha256-Mk3czMiTfdMTldTukqLZoiFUlWAklfHkv2tH5AbQXIw=";
    };
  };
  "4.1.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-LE590+AblCl5Wtw8cc1Ai+BcgBXkXeBRzuRJCPlQ2og=";
      "aarch64-linux" = "sha256-5fslEDxs6k2Q+ewMk0ZKLUZwxTeBdvpUvKiUEqBzSeU=";
    };
  };
  "4.1.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-86C1Z4rlnExW55EwO92qcITIcu3HIigialJUB+6m63k=";
      "aarch64-linux" = "sha256-0+ppWC9a4yEvnLRi2gXzsDUcjhonLY9mWtj3NbUDNec=";
    };
  };
  "4.1.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-0K/4CPTbuW62Udn8iRyiaDU0u7/Jc2SIImyprV/v7iU=";
      "aarch64-linux" = "sha256-Qg3dMt63k4LwM73BdK1sTNHlh/IOQXkTS0WEfGqKSTA=";
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
      "x86_64-linux" = "sha256-5qn5LzyB1dwnFuti/9LywHPfZmhVBcEfBZ9OmhXjx2Q=";
      "aarch64-linux" = "sha256-I6aEV+M/QlrqMSXlTFqTqpSC1oOudLG0sHuLoExN6zI=";
    };
  };
  "4.2.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-9tPaN7ghyieFfEInUqhwVuogGsylQ2dhR1m9rDTHgQ0=";
      "aarch64-linux" = "sha256-M1hQbQ0IB7y3wcZ6tFZdhHDv9t2puyLl9yS5HGdmNQA=";
    };
  };
  "4.2.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-hKdZvLvApdVOiTqHIsVVPKSbuF/qrp+CmSBgPklvRr0=";
      "aarch64-linux" = "sha256-NpvCopIon/KCq/9S/FVnLqSufDcqISNxy5l+E5dKoEA=";
    };
  };
}
