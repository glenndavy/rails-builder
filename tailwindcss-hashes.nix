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
      "x86_64-linux" = "sha256-j6R39E2X9r04du0xYg4n3Nb1vnbWzHlticuLLjao6ys=";
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
      "x86_64-linux" = "sha256-xJD/NLZu1ZJ6EffNm4gig9aB+LWuRtgg18X1N4cbZTI=";
      "aarch64-linux" = "sha256-CcWOsgK1M5Nkxwqnzgbz3uGOmcUpyYYlM7TBDM0EdJ8=";
    };
  };
  "4.0.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-e+qYK7+JQAvDKDUfx5Caku9u/B2/NIdHpDFcII92u7s=";
    };
  };
  "4.0.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-zcozUMCwQ1aeNE5A3K6SKIFWC6cWIQUnJLs2o9RlHqw=";
    };
  };
  "4.0.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-+ViuFNNyTXMXqDG1q81uAM/MnDDfI1ho4VysVENAtpg=";
    };
  };
  "4.0.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-p7Mw+sL5om1oPbkFJ/H8q1EMKV2lSukW+bWpMIR5MCE=";
    };
  };
  "4.0.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-fKxEUS96XWVZIBVSJ8ZLA15scEKrHMwdohOF8cPo+xs=";
    };
  };
  "4.0.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-BEinvRTdqO1qae94fP1ED+a51cHShxTbJRNz8jD9RFk=";
    };
  };
  "4.0.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-qGaS6Mc36NbbwNVGnwEI6ODppqzCJTgwOJUykXFGqds=";
    };
  };
  "4.0.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-hXhKKJVvuq2oWYxu6QmPm+9GtBX2DFMR9kZTm5p1cT4=";
    };
  };
  "4.0.16" = {
    npmDeps = {
      "x86_64-linux" = "sha256-OcgMilXbIb3vcLyzCkrGks1ywKlYG+A1/BA3lHme4+s=";
    };
  };
  "4.0.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-8wJm6nmccWa1EZla90A6ya+ac1LMRuTav6ZRLDi7ZYk=";
    };
  };
  "4.0.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-JBSoC6AG1UVaTyPwh/Q8ES2Ll23viIRAg2sJcl3GTRc=";
    };
  };
  "4.0.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-TfdEuOoGkCnZ62tP2s7LekP6WYm5qVIIWFha1PKYx8w=";
    };
  };
  "4.0.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-7o6GMWnkU1l96MpuPCo5KjUOGp85wsfx6e9mQux7yGw=";
    };
  };
  "4.0.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-EuSfaCGBPDibxEUzY20UpWxZhYI/qX1czBeFQc2/oi0=";
    };
  };
  "4.0.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-J6+FTszOawpO7XcfbZcBzkrZ5BMyzwPxr44fTh+kAZs=";
    };
  };
  "4.0.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-IjDnnW5XRYIXmqWcuiFrJDtrmcAUAvkUyzVV5rvTqac=";
    };
  };
  "4.0.8" = {
    npmDeps = {
      "x86_64-linux" = "sha256-8NZAHawQQPsvmBEz0WVz0baS7ivYRA99TvAfxvaTipE=";
    };
  };
  "4.0.9" = {
    npmDeps = {
      "x86_64-linux" = "sha256-WBKaKIxidc2DP4qU1a8bsGXzvT070kar/ULnyOB08bM=";
    };
  };
  "4.1.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-q/8l61UlokVTgc+DoOTjsYdmi3i6SqOsIJH4v91Qzps=";
    };
  };
  "4.1.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-bCH4Hvnyj0CX+M6gYlS2YfhKo3LSytEX71fy82PBXTE=";
    };
  };
  "4.1.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-4aWN2KYYR3lUdW6AtG6/6TUv8IKx0L302JBhrQAtPag=";
    };
  };
  "4.1.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-yqcVigRAALV8xCdBnbav1BV5mP3++BopYQCVnyU/Dzo=";
    };
  };
  "4.1.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-+1FHiqRRXjxKmbYF+ClxKPPUTnlXFM4BwYm8SakP0XY=";
    };
  };
  "4.1.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-2uy0RDHeHCRseCHvk3+0kKGp20hqrk0EX0VOrVvlsEM=";
    };
  };
  "4.1.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-YkGah9sf7DSk3wpvNvY3XTuxVxNebLie4VbO1VURKSk=";
    };
  };
  "4.1.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-o8IEGW4LyBHfhVbbl2txC2TSQyCemy7gUMddALaaO24=";
    };
  };
  "4.1.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-dX3cBnEmRFih+osy6y81PVUQ/iDgz85LaR2zZjVaL+g=";
    };
  };
  "4.1.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-IRADlh4YSljmJubUQCsMnnqP/2yZSn7E9Yn/kanXV5E=";
    };
  };
  "4.1.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-QpynY1dSIKFJq78cAU2s0Ub+U0x2JOarJg5u0tfFmEY=";
    };
  };
  "4.1.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-mxaMbDoKQXz0ECvO90W9FZCJseWM9NNoSxhv+tq/BZM=";
    };
  };
  "4.1.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-WeGvdFv2nebTZQG0gfBjPP9RM43ZX00h+WVbpHvnfZQ=";
    };
  };
  "4.1.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-pTznsXFmVU3CKoXB+DGN0xUXU3P6b1l1+ClZhf4+HV4=";
    };
  };
  "4.1.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-ZRVJCR53TXLF5kUSwQa8vxW4ilTb5tMSvcKBQjnPSKE=";
    };
  };
  "4.1.8" = {
    npmDeps = {
      "x86_64-linux" = "sha256-5g6nB526K1VkzHGmPifxFbzk08v7W73ZbB4DG0eXOUs=";
    };
  };
  "4.1.9" = {
    npmDeps = {
      "x86_64-linux" = "sha256-6CxUjsfhX9NJ2EXHlXECT3aRiRRMfnZUSF4rhZY5ubo=";
    };
  };
  "4.2.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-/aT7VWU3spU2j70VLzECfkxgVO/gPJQxqci1a7mN2uo=";
    };
  };
  "4.2.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-UsFMfIfnxBYKg+W9VBE6oVnXfzE2me36CmvyWGHloQs=";
    };
  };
}
