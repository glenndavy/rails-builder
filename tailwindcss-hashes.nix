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
      "aarch64-linux" = "sha256-JMvJaBXDG9FjObOs7bU31s2Spejyx/qepjHS3E7QYGI=";
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
      "x86_64-linux" = "sha256-xJD/NLZu1ZJ6EffNm4gig9aB+LWuRtgg18X1N4cbZTI=";
      "aarch64-linux" = "sha256-xT5uAsoiWYDOUpNyYFxwAVvYQUqthj9UawxOQIOeQto=";
    };
  };
  "4.0.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-e+qYK7+JQAvDKDUfx5Caku9u/B2/NIdHpDFcII92u7s=";
      "aarch64-linux" = "sha256-UoHFKH137MLODUoIX7PSMJU0/K04fRpWbqF+uW8ucj8=";
    };
  };
  "4.0.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-zcozUMCwQ1aeNE5A3K6SKIFWC6cWIQUnJLs2o9RlHqw=";
      "aarch64-linux" = "sha256-f+g7vyYHMWMuj6OhYN/pIhV9rRWzFeUZkP59rUChfaA=";
    };
  };
  "4.0.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-+ViuFNNyTXMXqDG1q81uAM/MnDDfI1ho4VysVENAtpg=";
      "aarch64-linux" = "sha256-cqpME98sWWwP9Vqiux72uGLHzNpSy+86uAADmFH5hiA=";
    };
  };
  "4.0.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-p7Mw+sL5om1oPbkFJ/H8q1EMKV2lSukW+bWpMIR5MCE=";
      "aarch64-linux" = "sha256-6eMm/22KdFs5bWz4gL4lUJs7feTC71sOL2Q7+YcH8IQ=";
    };
  };
  "4.0.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-fKxEUS96XWVZIBVSJ8ZLA15scEKrHMwdohOF8cPo+xs=";
      "aarch64-linux" = "sha256-3y3836IiK61Tb1e9U1YZLGnpnAP/tXOkTzCjub+DmcQ=";
    };
  };
  "4.0.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-BEinvRTdqO1qae94fP1ED+a51cHShxTbJRNz8jD9RFk=";
      "aarch64-linux" = "sha256-P1+AgHanqNmHmgTLUe3Vpiqeb6oWbueoGzOUXHU6NYs=";
    };
  };
  "4.0.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-qGaS6Mc36NbbwNVGnwEI6ODppqzCJTgwOJUykXFGqds=";
      "aarch64-linux" = "sha256-qYxu70nHfWoj22CmPItQqAm/HRr7IhdEWYAnVoGiHSA=";
    };
  };
  "4.0.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-hXhKKJVvuq2oWYxu6QmPm+9GtBX2DFMR9kZTm5p1cT4=";
      "aarch64-linux" = "sha256-VzGDsjaJq9CMyux2lF9hNS/kzzwQBdyEaoquUtZJBp8=";
    };
  };
  "4.0.16" = {
    npmDeps = {
      "x86_64-linux" = "sha256-OcgMilXbIb3vcLyzCkrGks1ywKlYG+A1/BA3lHme4+s=";
      "aarch64-linux" = "sha256-nlG0KxcJhMW7qxuoonzp+UuBR+zk689t8zs0ZMwuC4k=";
    };
  };
  "4.0.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-8wJm6nmccWa1EZla90A6ya+ac1LMRuTav6ZRLDi7ZYk=";
      "aarch64-linux" = "sha256-QNQMbJP9HelzUoBjOkASkjg64W2jZk4YMs0moQoQK7Y=";
    };
  };
  "4.0.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-JBSoC6AG1UVaTyPwh/Q8ES2Ll23viIRAg2sJcl3GTRc=";
      "aarch64-linux" = "sha256-iOeR/EiV+kGx6bDYjZkByjhua0iy8gBmBvoQWXvel+g=";
    };
  };
  "4.0.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-TfdEuOoGkCnZ62tP2s7LekP6WYm5qVIIWFha1PKYx8w=";
      "aarch64-linux" = "sha256-m2P+o2wn7Ax9M0HId7cwWBanCMSKJimY/hxuAg/Awdo=";
    };
  };
  "4.0.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-7o6GMWnkU1l96MpuPCo5KjUOGp85wsfx6e9mQux7yGw=";
      "aarch64-linux" = "sha256-8xyfGJ3dGNUnbV9xbzrDXIyRnzlkB2bJMUBGsLp/X38=";
    };
  };
  "4.0.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-EuSfaCGBPDibxEUzY20UpWxZhYI/qX1czBeFQc2/oi0=";
      "aarch64-linux" = "sha256-kfM7zfpJxBOpP4WTTOikgQJEJ+JZMPswRlbZwkWZX00=";
    };
  };
  "4.0.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-J6+FTszOawpO7XcfbZcBzkrZ5BMyzwPxr44fTh+kAZs=";
      "aarch64-linux" = "sha256-aLg8uNiR2AwywpLW6o2UDmphMRI4g85tBJQ6WuiTokQ=";
    };
  };
  "4.0.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-IjDnnW5XRYIXmqWcuiFrJDtrmcAUAvkUyzVV5rvTqac=";
      "aarch64-linux" = "sha256-Ad1PbBT+PG6jBs2E7aERP0QndyauPLkQ3TdIN+7UA9I=";
    };
  };
  "4.0.8" = {
    npmDeps = {
      "x86_64-linux" = "sha256-8NZAHawQQPsvmBEz0WVz0baS7ivYRA99TvAfxvaTipE=";
      "aarch64-linux" = "sha256-p3Wy3SIwBr7M54kjWAH7aCLQFAlJG4dxhy/Mn1R3RIc=";
    };
  };
  "4.0.9" = {
    npmDeps = {
      "x86_64-linux" = "sha256-WBKaKIxidc2DP4qU1a8bsGXzvT070kar/ULnyOB08bM=";
      "aarch64-linux" = "sha256-mFVe2JWPJPk3LgUKnAAHXsl0QTCMvNbDw8RMsSWtEEM=";
    };
  };
  "4.1.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-q/8l61UlokVTgc+DoOTjsYdmi3i6SqOsIJH4v91Qzps=";
      "aarch64-linux" = "sha256-osK1f+Txh3PnCX7E65Y/IwB/lz2FubLYd4El+8vzmKI=";
    };
  };
  "4.1.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-bCH4Hvnyj0CX+M6gYlS2YfhKo3LSytEX71fy82PBXTE=";
      "aarch64-linux" = "sha256-/z/9pqXtUpYMvNlSoqtVfxFe+moCj4Eb98zFpl2blYw=";
    };
  };
  "4.1.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-4aWN2KYYR3lUdW6AtG6/6TUv8IKx0L302JBhrQAtPag=";
      "aarch64-linux" = "sha256-mRG9mS+YKF1GdnxMdgiigYYXqG7Ql12n4xT5AagNA90=";
    };
  };
  "4.1.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-yqcVigRAALV8xCdBnbav1BV5mP3++BopYQCVnyU/Dzo=";
      "aarch64-linux" = "sha256-v60h3G8QwALbKymSqehg0iEiahvIAaRacV2pvh5yWRo=";
    };
  };
  "4.1.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-+1FHiqRRXjxKmbYF+ClxKPPUTnlXFM4BwYm8SakP0XY=";
      "aarch64-linux" = "sha256-WMQiWKPlu/VeK7rta6ORz6to33eszpna+krlLrNO1sY=";
    };
  };
  "4.1.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-2uy0RDHeHCRseCHvk3+0kKGp20hqrk0EX0VOrVvlsEM=";
      "aarch64-linux" = "sha256-GuRJumNymnz4WDKTOb5wmhMUQAtDnXqTJ+RBBSTl+wg=";
    };
  };
  "4.1.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-YkGah9sf7DSk3wpvNvY3XTuxVxNebLie4VbO1VURKSk=";
      "aarch64-linux" = "sha256-W7eCVbCTL2o6H1I45Zw2dAPnKhJiJl81QP9HH9dAqNI=";
    };
  };
  "4.1.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-o8IEGW4LyBHfhVbbl2txC2TSQyCemy7gUMddALaaO24=";
      "aarch64-linux" = "sha256-g0tQ9H5fc0vv1BnWTe0ntPkgfmnzLtPayy3UUlELgQc=";
    };
  };
  "4.1.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-dX3cBnEmRFih+osy6y81PVUQ/iDgz85LaR2zZjVaL+g=";
      "aarch64-linux" = "sha256-4uemvj21zAFqlpIZ0lLqXKcrfHnQpsHmAWlljj4idxo=";
    };
  };
  "4.1.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-IRADlh4YSljmJubUQCsMnnqP/2yZSn7E9Yn/kanXV5E=";
      "aarch64-linux" = "sha256-QzMI6rtQVWOmZwW0g729NqCEMy8jVDhySl0T0PBmuek=";
    };
  };
  "4.1.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-QpynY1dSIKFJq78cAU2s0Ub+U0x2JOarJg5u0tfFmEY=";
      "aarch64-linux" = "sha256-VLh+AFLf+mk+mcRNG6SJ0BPkCwZwamFfbfBYCZaCMAE=";
    };
  };
  "4.1.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-mxaMbDoKQXz0ECvO90W9FZCJseWM9NNoSxhv+tq/BZM=";
      "aarch64-linux" = "sha256-sRqgrmAku6wJNacUFSmRlpc5evwENA+PQA+ewdcxrTg=";
    };
  };
  "4.1.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-WeGvdFv2nebTZQG0gfBjPP9RM43ZX00h+WVbpHvnfZQ=";
      "aarch64-linux" = "sha256-Bz1v/5NnHguyvWDuokK3fb0Mj8RKS0Aray7GUwfKve0=";
    };
  };
  "4.1.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-pTznsXFmVU3CKoXB+DGN0xUXU3P6b1l1+ClZhf4+HV4=";
      "aarch64-linux" = "sha256-mxBsq6gaxjglCH0fGqqrj0Hr95hljNOrj+krloDAaa8=";
    };
  };
  "4.1.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-ZRVJCR53TXLF5kUSwQa8vxW4ilTb5tMSvcKBQjnPSKE=";
      "aarch64-linux" = "sha256-XN+RvKlPc14Uo1alAJ3v+a8vJEPbDtD46xSmfEXT5M0=";
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
      "x86_64-linux" = "sha256-6CxUjsfhX9NJ2EXHlXECT3aRiRRMfnZUSF4rhZY5ubo=";
      "aarch64-linux" = "sha256-DyM+7qNux5arvJ4kTqztwmeDzl7zUGGQE2ny4dp7N/A=";
    };
  };
  "4.2.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-/aT7VWU3spU2j70VLzECfkxgVO/gPJQxqci1a7mN2uo=";
      "aarch64-linux" = "sha256-XQJpRmecmo5ajTXuhignAIJspq+5whs+NErLuKGfUds=";
    };
  };
  "4.2.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-UsFMfIfnxBYKg+W9VBE6oVnXfzE2me36CmvyWGHloQs=";
      "aarch64-linux" = "sha256-iHFc0QTyEyBmwDFmcrem5cpU8QOoCwsPbFs/WHGE0cU=";
    };
  };
}
