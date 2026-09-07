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
      "x86_64-linux" = "sha256-0uGaTlgdleb/pGhz0IRtD9PwjkUi4kp/2CbU4AZ5mRM=";
      "aarch64-linux" = "sha256-62ddVA9u8bzmZtnKQsIIvgr39y2UmkjxRjGwTm2pPT8=";
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
      "x86_64-linux" = "sha256-tBn3wlPmBVb6oDUPpqntOdyCrVP6dleZNhVNu4eNLjk=";
      "aarch64-linux" = "sha256-rmAuc8DNFWRWaCC0c2lIFsd8vGKzuFH0DSCbFN86vQc=";
    };
  };
  "4.0.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-M0sW5sh6QFSvkhzrJ0SaH4KcPfunoz19I9OTwUKLS4E=";
      "aarch64-linux" = "sha256-MdxQPDQRclnJQP46eWBdPyxxKfLeO66/83TfGG+6c3c=";
    };
  };
  "4.0.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-2AEJ8lZw7jBKOGNqOrDXR4KF0r47T1RYOsy/vMDMdDA=";
      "aarch64-linux" = "sha256-uJBSo4c4wLMNLhHq/1dkTcut6LmXuwlXbXRAB1Jp2VM=";
    };
  };
  "4.0.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-T+BZHbme48Rh+HraZxwXRKWNLG3VEncWUKqRdoAVAZY=";
      "aarch64-linux" = "sha256-JRviX4izTup9NMtPtMnQooUbYt7fjh7u6MB2GIweSxk=";
    };
  };
  "4.0.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-iYyQ2hFFR0bgTQ6r2mmWwjNyOaK68hZWd5QNxpYzaVc=";
      "aarch64-linux" = "sha256-RARj/A9bfRrLnckbffnZcXNSj/yYqgcmR+8E1cbQT4w=";
    };
  };
  "4.0.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-+aWH4tew9/M8+JxGfMA9h8VZUehZRGaTd2rwm93MkJ4=";
      "aarch64-linux" = "sha256-xw7GEMY+aoYN0kGLPbJP1SMayCsuwawZ5fx/CAhDCiU=";
    };
  };
  "4.0.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-vFxq9Gl8dY3G1ldQsP/KE49wCb21XtESQnTgQAuBWlA=";
      "aarch64-linux" = "sha256-v6/bHj516MghbF71IzjXZnSr4H8l4MiAukeOcBzjyMc=";
    };
  };
  "4.0.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-5uwqTeU7AqgImmiEXWb+/xPNXz1CeRKq6wQZ9R9xWF4=";
      "aarch64-linux" = "sha256-/ZAe9L74qLTk8V8WcB+x8aIoORHyTsjeEsqPw/18FQY=";
    };
  };
  "4.0.16" = {
    npmDeps = {
      "x86_64-linux" = "sha256-6Kg7l/CgJ/emk/AmlvAIyYIjXtcFygVD1iItE3sSPSQ=";
      "aarch64-linux" = "sha256-yRQCJPpdKZ/eMrgyA28g/LTuxQf2vULbZfSshKHw2h4=";
    };
  };
  "4.0.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-+6OZ/UVwX+uYYAQhVI6YtIBugqYt5L5RfsPsx3VoUtw=";
      "aarch64-linux" = "sha256-pGMPBj4TfHVmSKQa+y3XeJE0CzhJelJ/oTGigdMKpso=";
    };
  };
  "4.0.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-IqR8UNAi8oUARlpdDB1SwYY4VznzvZBFHhrdfqweqL8=";
      "aarch64-linux" = "sha256-/+QWnjivvmWLLMSqAhPp/drIBL6+ZNB6VGGsWmEEuZs=";
    };
  };
  "4.0.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Sfn/3caulSatkx41jisb/Io/rI+DzkBiM/+GVfZA+M0=";
      "aarch64-linux" = "sha256-4w7HlGbOWp+SaCyl0sorY4Peba/5mZEWHA4g1bf6A4M=";
    };
  };
  "4.0.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-j7AIvGcJXv3l7mpa5CdI0L5aldxdwTsjJ8BbWmwRbMQ=";
      "aarch64-linux" = "sha256-FMzd+oPryD0XO9TdIHUPfD4vA0Y5XBem4gGG9DkEiJE=";
    };
  };
  "4.0.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-cykeQaXhLiabFa1pr/UicUfj1uQF28GJbonHF6Crk+0=";
      "aarch64-linux" = "sha256-Q7aTq+t6gN7bgO/u2dUg6tnx9TzbSiy7rratluN3un8=";
    };
  };
  "4.0.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-crl2x+FDuGh2+eSNOgZCbi2/WdrMEAMWkM3+bXRtlM8=";
      "aarch64-linux" = "sha256-+8vciKJl2I0fHB2B99j63U8ylay6XYdgN5ds7uqzrAE=";
    };
  };
  "4.0.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-pwtR5vZEj5KlG4Q+5sbYFUiAmsRXtPU0BVlU+cO/JaE=";
      "aarch64-linux" = "sha256-9kRXNI2OKktmpJbsWSI7kIXuEufSLlOkfqDjIGicHfk=";
    };
  };
  "4.0.8" = {
    npmDeps = {
      "x86_64-linux" = "sha256-RDoTL2c3S5sThVt6ge2ql+eueJZjgC8dXjk07ROcdMM=";
      "aarch64-linux" = "sha256-zXoWDNVVNVguYrmhRoqYuh8sa0Rv2fO5cbXK/oKJKls=";
    };
  };
  "4.0.9" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Tp46V4cOHNXSm0cXsmxMS42VZ451ua+xYVQnEQDkUGY=";
      "aarch64-linux" = "sha256-lZhrQKJmQHQqtOp8kZtGs49GIn/x7MlFOS8m2Le5pE8=";
    };
  };
  "4.1.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-yA2LKpL2NPy4HOx0VwrfQC2QMTSkcy7HsltaxEbszmU=";
      "aarch64-linux" = "sha256-p7u1RBLJt11tRWw4vikKp2gLClsK8rSKV5hlKx4aSH8=";
    };
  };
  "4.1.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-72zWG955bd5U+lQH08czHBuQ1C/rrDDXHoig9C0z13M=";
      "aarch64-linux" = "sha256-fMO19NvFO9gb+UQhr0dY8DyPNLIw2ROe2W+RvIopv1o=";
    };
  };
  "4.1.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-uofeEGPV4lgn/HhwZMjjmLZohw5UUwWCs1NxOq9US7U=";
      "aarch64-linux" = "sha256-j7SrPLla8NH0EFAGlt0SoIiKoVfeayQJ9lqO3URUwL8=";
    };
  };
  "4.1.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-mChIEmwsVEJubtlZVM1MCCCObHMdCS96KZiH5xjOg7c=";
      "aarch64-linux" = "sha256-9TkZqKg2AizfXQnsFlb3jcwWVsKOhwTO4/zTkARp5UM=";
    };
  };
  "4.1.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-wewehJtT40rxDNCgrpDkc95rBJJSd4uIsdEYz29varY=";
      "aarch64-linux" = "sha256-4lPXiT3K61p/+Eimc0S+e3Mvh8QeOa7eYTrCIUZHB+Y=";
    };
  };
  "4.1.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-WBzckCKuaz+KEMHO2omomymgQ8OOD8SNG3My5QWgsJo=";
      "aarch64-linux" = "sha256-jFxL3s2YFyH2rCAdriq8P3hHaIoQMVjvpZVTLucF2ww=";
    };
  };
  "4.1.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-C8BKjksh1aXkad217rFSJdQGFqsE35RmeiCsUoxye4Q=";
      "aarch64-linux" = "sha256-jFH+n7+6ohNpgASceqPY9uoMlhwtn9b4f3uSquY+Ymg=";
    };
  };
  "4.1.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-LJLjIRTDJ7T0PQGAjieusKeYo0BozmFdHBCgL6T+TEE=";
      "aarch64-linux" = "sha256-TS3DXgn92PtRqJf0rYJNql+/s+xnsBpr9HL+pufRlcI=";
    };
  };
  "4.1.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-BIPFWVNJlDYHA3sLSojtfaHocp5KAzxaFreFYbM9UPU=";
      "aarch64-linux" = "sha256-PMCJGYoPz+ZGgrhMzB9cOPi8fpgxCgIZwbL9bfKVfa0=";
    };
  };
  "4.1.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-eKHR+p1Z1Qx6rTMBaqmC5oQqoLbEY/G1aSiXQc4PKgs=";
      "aarch64-linux" = "sha256-u0D1TVVyhrG4pl1ebPOkE1BXSYqSMpYw1aHUsancBlo=";
    };
  };
  "4.1.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-zsgr8FKYt3/arD7yd+g/RuD/6RmS0zFnr03OlcLwKiQ=";
      "aarch64-linux" = "sha256-cuKh6nYNOUcrJ/Zif4Uee8HBrsm33eWpVR6VqN9/9zw=";
    };
  };
  "4.1.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-lquYlF3Y8sxlNeMgOFVz5B0rWYCdps4mmtI1LLxTUW0=";
      "aarch64-linux" = "sha256-qxk5pwZ6h8eKA2ZX34MuZW4jsTwk5EIGym8vzKETfFg=";
    };
  };
  "4.1.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-B9g5Zi5sdZYogXEMWk8gDppnopJCyxEdmZhBR4hWulA=";
      "aarch64-linux" = "sha256-0xdaG3x1oBm0Tj6A7TobzPKZYs0R48hvxBX7Skt6EhU=";
    };
  };
  "4.1.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-G5XD8Nzl364vx2oyTUtY+M7T1+J8CrDCMwhY/Pk0Mwk=";
      "aarch64-linux" = "sha256-EALYKyfRxJXp4pMPUjiPiNZ07MWBFbvlGjTI2ynlqng=";
    };
  };
  "4.1.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-iZ3ExGQQIvcBWC/VJUnTCeSUuu+qRUkqLhd/6P8QBnI=";
      "aarch64-linux" = "sha256-AC/v8tYDas23G09WnQYNoWAbepOOgK0iP0pXAiQLnO8=";
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
      "x86_64-linux" = "sha256-F0P7lWy4nmjvKU4LUvPliD9edIVcUw5FZrl57JENqFQ=";
      "aarch64-linux" = "sha256-xFeRMwzS9Pv+fX/3j3fNFKtCjgIDkQvlDeYaJAkMCB8=";
    };
  };
  "4.2.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-cE6EPltef79HZnlGftklbp3TFb+TA5Yqy9vlfv9/mwY=";
      "aarch64-linux" = "sha256-LPXxzHXTLNA6LT7gVpbmcH2gE9F26bRoDqA7oox6Uls=";
    };
  };
  "4.2.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-BHpV842RfeAkGS1GBLzo7LhTTSlwaQEtHXYPjyVf5Zg=";
      "aarch64-linux" = "sha256-btLkj2KF7O55K30lGWdEJ90fB+UUFCYGJvZaMpmtLd8=";
    };
  };
}
