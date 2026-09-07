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
      "x86_64-linux" = "sha256-tBn3wlPmBVb6oDUPpqntOdyCrVP6dleZNhVNu4eNLjk=";
    };
  };
  "4.0.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-M0sW5sh6QFSvkhzrJ0SaH4KcPfunoz19I9OTwUKLS4E=";
    };
  };
  "4.0.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-2AEJ8lZw7jBKOGNqOrDXR4KF0r47T1RYOsy/vMDMdDA=";
    };
  };
  "4.0.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-T+BZHbme48Rh+HraZxwXRKWNLG3VEncWUKqRdoAVAZY=";
    };
  };
  "4.0.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-iYyQ2hFFR0bgTQ6r2mmWwjNyOaK68hZWd5QNxpYzaVc=";
    };
  };
  "4.0.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-+aWH4tew9/M8+JxGfMA9h8VZUehZRGaTd2rwm93MkJ4=";
    };
  };
  "4.0.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-vFxq9Gl8dY3G1ldQsP/KE49wCb21XtESQnTgQAuBWlA=";
    };
  };
  "4.0.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-5uwqTeU7AqgImmiEXWb+/xPNXz1CeRKq6wQZ9R9xWF4=";
    };
  };
  "4.0.16" = {
    npmDeps = {
      "x86_64-linux" = "sha256-6Kg7l/CgJ/emk/AmlvAIyYIjXtcFygVD1iItE3sSPSQ=";
    };
  };
  "4.0.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-+6OZ/UVwX+uYYAQhVI6YtIBugqYt5L5RfsPsx3VoUtw=";
    };
  };
  "4.0.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-IqR8UNAi8oUARlpdDB1SwYY4VznzvZBFHhrdfqweqL8=";
    };
  };
  "4.0.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Sfn/3caulSatkx41jisb/Io/rI+DzkBiM/+GVfZA+M0=";
    };
  };
  "4.0.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-j7AIvGcJXv3l7mpa5CdI0L5aldxdwTsjJ8BbWmwRbMQ=";
    };
  };
  "4.0.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-cykeQaXhLiabFa1pr/UicUfj1uQF28GJbonHF6Crk+0=";
    };
  };
  "4.0.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-crl2x+FDuGh2+eSNOgZCbi2/WdrMEAMWkM3+bXRtlM8=";
    };
  };
  "4.0.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-pwtR5vZEj5KlG4Q+5sbYFUiAmsRXtPU0BVlU+cO/JaE=";
    };
  };
  "4.0.8" = {
    npmDeps = {
      "x86_64-linux" = "sha256-RDoTL2c3S5sThVt6ge2ql+eueJZjgC8dXjk07ROcdMM=";
    };
  };
  "4.0.9" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Tp46V4cOHNXSm0cXsmxMS42VZ451ua+xYVQnEQDkUGY=";
    };
  };
  "4.1.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-yA2LKpL2NPy4HOx0VwrfQC2QMTSkcy7HsltaxEbszmU=";
    };
  };
  "4.1.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-72zWG955bd5U+lQH08czHBuQ1C/rrDDXHoig9C0z13M=";
    };
  };
  "4.1.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-uofeEGPV4lgn/HhwZMjjmLZohw5UUwWCs1NxOq9US7U=";
    };
  };
  "4.1.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-mChIEmwsVEJubtlZVM1MCCCObHMdCS96KZiH5xjOg7c=";
    };
  };
  "4.1.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-wewehJtT40rxDNCgrpDkc95rBJJSd4uIsdEYz29varY=";
    };
  };
  "4.1.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-WBzckCKuaz+KEMHO2omomymgQ8OOD8SNG3My5QWgsJo=";
    };
  };
  "4.1.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-C8BKjksh1aXkad217rFSJdQGFqsE35RmeiCsUoxye4Q=";
    };
  };
  "4.1.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-LJLjIRTDJ7T0PQGAjieusKeYo0BozmFdHBCgL6T+TEE=";
    };
  };
  "4.1.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-BIPFWVNJlDYHA3sLSojtfaHocp5KAzxaFreFYbM9UPU=";
    };
  };
  "4.1.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-eKHR+p1Z1Qx6rTMBaqmC5oQqoLbEY/G1aSiXQc4PKgs=";
    };
  };
  "4.1.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-zsgr8FKYt3/arD7yd+g/RuD/6RmS0zFnr03OlcLwKiQ=";
    };
  };
  "4.1.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-lquYlF3Y8sxlNeMgOFVz5B0rWYCdps4mmtI1LLxTUW0=";
    };
  };
  "4.1.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-B9g5Zi5sdZYogXEMWk8gDppnopJCyxEdmZhBR4hWulA=";
    };
  };
  "4.1.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-G5XD8Nzl364vx2oyTUtY+M7T1+J8CrDCMwhY/Pk0Mwk=";
    };
  };
  "4.1.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-iZ3ExGQQIvcBWC/VJUnTCeSUuu+qRUkqLhd/6P8QBnI=";
    };
  };
  "4.1.8" = {
    npmDeps = {
      "x86_64-linux" = "sha256-5g6nB526K1VkzHGmPifxFbzk08v7W73ZbB4DG0eXOUs=";
    };
  };
  "4.1.9" = {
    npmDeps = {
      "x86_64-linux" = "sha256-F0P7lWy4nmjvKU4LUvPliD9edIVcUw5FZrl57JENqFQ=";
    };
  };
  "4.2.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-cE6EPltef79HZnlGftklbp3TFb+TA5Yqy9vlfv9/mwY=";
    };
  };
  "4.2.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-BHpV842RfeAkGS1GBLzo7LhTTSlwaQEtHXYPjyVf5Zg=";
    };
  };
}
