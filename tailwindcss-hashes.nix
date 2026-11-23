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
      "x86_64-linux" = "sha256-RyBN8PbZziOeFAn5jqkPgciOG/1SDsd2vOMhjsOfdxA=";
    };
  };
  "4.1.18" = {
    npmDeps = {
      "x86_64-linux" = "sha256-DZDwT9B/gEyRkCIwPRStuKjYoRyIrtmVIwFTTiSsKww=";
    };
  };
  "4.2.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-CLlwydSvbyzA3fNNs9U7BG8wwBuKG2WqhnX1GDmOOHQ=";
      # History: re-pinned repeatedly on 2026-08-18 while the install
      # was unfrozen (V4Gu… → GbW0… → jZTjh…). Re-verified 2026-11-23
      # with the frozen lockfile under bun 1.3.13 and 1.4.4.
      "aarch64-linux" = "sha256-GbW0mDnCufoSanDSKSWIM86srFLLiJB3ZdwGyfmbSjU=";
    };
  };
  "4.2.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-q6fgyfevbmh4CbB/atXqTFcFeYm0h/JTvRrImnEIP5Y=";
    };
  };
  "4.2.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-8S7PG3vgyXBRU5xXW4U5XuSfIZmI4Gs1v44M0OVeQjQ=";
    };
  };
  "4.3.0" = {
    npmDeps = {
      # History: this pin flip-flopped between zovIIqJ… (botman-box
      # production), +n6zOE… and l2AwUOc… (local dev builds).
      # Re-verified 2026-11-23 with the frozen lockfile: bun 1.3.13
      # (rails-builder's pinned nixpkgs) and bun 1.4.4 (nixos-unstable)
      # both produce the values below on both arches.
      "x86_64-linux" = "sha256-zovIIqJOnRiaAaxKt/tniKlM+QWqAzBkk8CMJ00KRvE=";
      "aarch64-linux" = "sha256-JR5ddZ0w5xpJkfkoSIJf7yKKqyzDWKZFtfWmK3qmp6U=";
    };
  };
  "4.0.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-TLEuw4mH4Cn233mwpy3TDxAI7Zvn+d4dDp8ASIL/dmc=";
    };
  };
  "4.0.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Os/IRPj0Se2S/qsOcGbS1TcG0uxlCrg6KaPmnQGypWQ=";
    };
  };
  "4.0.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-XXVflc1et+Gk9Elw9guOnAr6fph7xuOAI3tgLXmhjvc=";
    };
  };
  "4.0.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-+bH6ZZIyg5RBWDUKsTLxi7EH4KIh6X39xe7t7XgFxmA=";
    };
  };
  "4.0.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-ivsi6JjGowVnFyHhyF1vITJ3Q8FawoXQ1h8PtPPOr3o=";
    };
  };
  "4.0.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-rLPJamBAHvCkY67doqkuVkBIUOIs0cLRw478a9UHxSc=";
    };
  };
  "4.0.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-9bizsL5svwLFHFcFzJ9A6ONJgc7soOy/nnK9VF0P0aI=";
    };
  };
  "4.0.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-/yenK4hiWiHiiCW0yL7rDYbZt4gsG2/XpqtNf+94/mU=";
    };
  };
  "4.0.16" = {
    npmDeps = {
      "x86_64-linux" = "sha256-uBiLDXmhS9LrBT30dfnLf58kchaSEvalfesT8Uub460=";
    };
  };
  "4.0.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-L7V7SRqwICCtvytI8eYtZDvR+DtBPkwZMGJB22GiBME=";
    };
  };
  "4.0.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-gZWYj96i14drrOL2bI5gU+nrvi7Aa1eqCIaddUf3zzM=";
    };
  };
  "4.0.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-zqFl+5OfY/xj66PXGxO5ibaXCBWy7lcLbw4QyIXb5bc=";
    };
  };
  "4.0.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-x2Alj9VXve6EGhv1gWQdnr76vtXNq8l8iN8CQWzFj60=";
    };
  };
  "4.0.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Gt5Uu7NJkgPldI57ji10CZumDwrL7aj3R5i0LkrhNgA=";
    };
  };
  "4.0.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-QERwC5Uh74jsSte+bIEpLOjl4pxj9pjX+YQhehHCvQQ=";
    };
  };
  "4.0.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-FKfWPoAt6/jQVJC/iYtfSjlHxUhBIXmE9iWyQll2UiU=";
    };
  };
  "4.0.8" = {
    npmDeps = {
      "x86_64-linux" = "sha256-QFS0S09SmrAQbQcAdZ5C+GLQ+mWGCWiSpOKUoPyh4QE=";
    };
  };
  "4.0.9" = {
    npmDeps = {
      "x86_64-linux" = "sha256-MDnPBt1q2C0hmNpG3I90XpkcyV/6l4W4cDqr4Qo0PTc=";
    };
  };
  "4.1.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-vj8ylVdD2IzU4vgyNDBQbUn20W05Ehgpm/x3SAZGKS8=";
    };
  };
  "4.1.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-GX2oSz6fmazx810Mhe9yCicrEPqjaZKwChPL2/xLJog=";
    };
  };
  "4.1.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-tk7nwLp5qjZz3YHhn+NXL76Rq0eaMame3i7FVv6d+Ig=";
    };
  };
  "4.1.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-XUnWGeQDr98FhyOpHzxM0SbUWNaCFQNtKKOIEFhptjg=";
    };
  };
  "4.1.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-UsuqayceZav/Gx6pLsdhpBm6DYZoBHa1mbq2BIPuyEQ=";
    };
  };
  "4.1.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-VvLG6iwCcN0y93dg6DMmGAB2XZR6Caw6bmE07odCfPc=";
    };
  };
  "4.1.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-2lUhKEAlbdlxsmaUxnaF1uNkDBNw0N7heUP4Z77Mfaw=";
    };
  };
  "4.1.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-xenFR7nxhTHRRMO5SAQG7xCe/PUCZjURUSQ6jfvkGBg=";
    };
  };
  "4.1.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Jq+DRbkhke6ecPWQtIxbbJIgrNrCWC4aBDoCSuRPcuc=";
    };
  };
  "4.1.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Z2p0tHm36rMGYi3p2JbFRRJqgC4xF65xT6koqK32KtI=";
    };
  };
  "4.1.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-hDN0tHluS/zQCR+44tbYBlEH5jZl/aOevFoDMdgolp4=";
    };
  };
  "4.1.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-nwMjKGh/0BJn6JKppN4io6633ij6ekevqC8ufseWvgU=";
    };
  };
  "4.1.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-tVmxMtLaRRRBgPQSnx5i77sHx2+8EgbUdeqxLg9FNrc=";
    };
  };
  "4.1.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-dveK72R+BY2L4jgjdv3Xqjjnpohvqj4dh7fmpwZ3Szk=";
    };
  };
  "4.1.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Nk8sLIFIWItEqmQgFzZBCWvSGXjB04qVqBnnUcEFkjg=";
    };
  };
  "4.1.8" = {
    npmDeps = {
      "x86_64-linux" = "sha256-E3qfXsIMt1U6QvDY0zInB23bLZ13ghoQG5fMkJ7uPqw=";
    };
  };
  "4.1.9" = {
    npmDeps = {
      "x86_64-linux" = "sha256-7Cy5EhEihTBa/fNK/fBf08HHZPfylkAQgVTqYuzHlyk=";
    };
  };
  "4.2.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-5nhCHZwmIEnO+d2ii8LADMDAXWVnVbT/A1N7IiT3lSQ=";
    };
  };
  "4.2.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-BGWHklNFhXqSf1bNPJ3HxjC7R2vkxou4yslG9fWZOAM=";
    };
  };
  "4.3.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-2g1t20J+PXYgrHhlOCYEPpYAFCdwH5OZ+snBMAdZLC0=";
      "aarch64-linux" = "sha256-Obb9n8JxHXvTcIhdTmA5p+V136lQASpRGINZLV1NhRw=";
    };
  };
  "4.3.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-AHoEonR9o3ambPZ+V51//Cojl6YzmSaiIiYzPIHMq2U=";
      "aarch64-linux" = "sha256-YmeG360VWOwS4Rt5qv4IqWOg1uqiM8oJSHAWkdSlHiY=";
    };
  };
  "4.3.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-IPJ+0c1h5W8OL0StATW8K3KhvyEfYi6Z4Zt9oUG3k9M=";
      "aarch64-linux" = "sha256-58GmJlERbWN7OjAqkvwJVYhDMAnWlLc8+PRStkmz16c=";
    };
  };
  "4.3.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-D53mu7bd6+zoBduk0vFZCniBxPtQPQETtplbiG61G9Q=";
      "aarch64-linux" = "sha256-dcYYXt3z1yQnuWXEDJukBnMLFg0weUZsWdsX0yTcKS8=";
    };
  };
  "4.3.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-didLCKOihWRuJMIsNdBIwYDmTOIdJDhg087bl2RCYsc=";
      "aarch64-linux" = "sha256-pAF6yivbdRxGV/gQDMiJMwoXJVfqaY9PHIqxjkrsLuY=";
    };
  };
}
