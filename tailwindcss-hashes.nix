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
      "x86_64-linux" = "sha256-iCsLpmgyyrit1Dw2SSIJre3+RYncsx7ftob0wZPmE20=";
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
      # History: re-pinned repeatedly on 2026-08-18 while the install
      # was unfrozen (V4Gu… → GbW0… → jZTjh…). Re-verified 2026-11-23
      # with the frozen lockfile under bun 1.3.13 and 1.4.4.
      "aarch64-linux" = "sha256-GbW0mDnCufoSanDSKSWIM86srFLLiJB3ZdwGyfmbSjU=";
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
      # History: this pin flip-flopped between zovIIqJ… (botman-box
      # production), +n6zOE… and l2AwUOc… (local dev builds).
      # Re-verified 2026-11-23 with the frozen lockfile: bun 1.3.13
      # (rails-builder's pinned nixpkgs) and bun 1.4.4 (nixos-unstable)
      # both produce the values below on both arches.
      "x86_64-linux" = "sha256-xJD/NLZu1ZJ6EffNm4gig9aB+LWuRtgg18X1N4cbZTI=";
      "aarch64-linux" = "sha256-JR5ddZ0w5xpJkfkoSIJf7yKKqyzDWKZFtfWmK3qmp6U=";
    };
  };
  "4.0.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-OhPmsqRL8znT+J7qKVN39wqmd5Hu9U3EI6m86EJWdRQ=";
    };
  };
  "4.0.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-A+HEZUt6kQUEHTLBApBLjeauJNqBlUX6VW8s1pnGv2o=";
    };
  };
  "4.0.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-099jZUPUtoFDdXUt7oBGpnN7Q8/OVt0+lJJVWR/8+jg=";
    };
  };
  "4.0.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-lOLDDxfVqr1zn2MEWT20NcaAHVfynkSvfgneGFxIGqs=";
    };
  };
  "4.0.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-9ksVnD+zG7vdJcvWD4ySyav+3MCRGW1X4uXDgC4k+Mo=";
    };
  };
  "4.0.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-RVDK4xDswAfFG+oZlh8+oaQY8T3Rc9wUIIQUcHgMUTA=";
    };
  };
  "4.0.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-uLb5dUZOLUOE+sdYMGR8L21xj+aK5Lgjhajq5TRbFYY=";
    };
  };
  "4.0.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-M4wEyFEPVqljhC+95n1m6orbypQmAZ15jwozQSDV+g8=";
    };
  };
  "4.0.16" = {
    npmDeps = {
      "x86_64-linux" = "sha256-ha+PrutmHpH+aWfM9jsEnX/sPa4ti5ezrz3xNRER0Es=";
    };
  };
  "4.0.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-hsiOley0GKuB+Y4crHrQ74bXswtfkWH5hNTQy44gwHQ=";
    };
  };
  "4.0.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-YJEmUqUtwIo77nW4q01203cqcydfWTrWcLcXETRFthE=";
    };
  };
  "4.0.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-OsKd/BUfQrcgszZGAaedN6FDJi1wcSiRpFO1FdQ6kwg=";
    };
  };
  "4.0.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-/e5J+p7GwqL6ZFMCsKCYZGsgfCbcjTJw6HckkFkZkDs=";
    };
  };
  "4.0.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-rw+6Kbu3TBo+/adAGWXeDONL4qVv3NuT5m4Fjo8+l0o=";
    };
  };
  "4.0.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-iKciDB7rX7sDx6ozZA4gCzAoh/2b9sAQ0iu1XhjbFrs=";
    };
  };
  "4.0.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-wmTfZ6tVXzMYtJdm7lSMlWMJA/54FO+0aWdpXPzbqig=";
    };
  };
  "4.0.8" = {
    npmDeps = {
      "x86_64-linux" = "sha256-09pj5Jw+VfjlT/KAUmlvZSd4rTNCm/KDJwFj9eDWIHU=";
    };
  };
  "4.0.9" = {
    npmDeps = {
      "x86_64-linux" = "sha256-3yv5bBoh7LZsKjYuErdVoBedtG8B1LqycO0hplIOZXw=";
    };
  };
  "4.1.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-X4tN0WRM0PZQVBKbaFKto0Fo52ywhnywS3cTNqTecD0=";
    };
  };
  "4.1.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-3W47oCXtt+cOkzkgMeL9fPmkLuRQagsa3WoUD3XJskc=";
    };
  };
  "4.1.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-6ihNmWOoMsCE2QXoOwMFa1AxT7ncRgfz3x2/ZypNU8g=";
    };
  };
  "4.1.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-RimvtyiIXaQGF0p0rCcuoSIkKnj8fifx7qebtfCh75s=";
    };
  };
  "4.1.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Uaje2AEtm3+qKnmWeP3dwlvqqyDeP8x5rAST8GL5NpQ=";
    };
  };
  "4.1.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-dV0ECzqSKZlJ/kSLxW4OUgt4YsUVAHFjPbBIG+rgCWE=";
    };
  };
  "4.1.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-GkAsJ2Dw8TCScJ5D+TsI0/CKwZ3oKfAO1KGbNFAOGFA=";
    };
  };
  "4.1.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-kSuXfKZwj9t3D6X3LBCTbj6c2K6MdaHnnz0HD4YKGEQ=";
    };
  };
  "4.1.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-saJaGXvD/erHP2KcfQgFn3FYsJfKdUwsumCntmknfk8=";
    };
  };
  "4.1.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-mZb8c5vxYjAuoktf6QmkkcmZWSb9F+sNRWOuWs5MMZ8=";
    };
  };
  "4.1.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-/LtjhHGyM56NM1uJnsoZyoFJgAMUHv7h3PleEsSyYiE=";
    };
  };
  "4.1.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-6wdGhp70f2SXtBtAibMqNsu/Dz9ksZqH4ry/P3PEveQ=";
    };
  };
  "4.1.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-7RFpvcglh/hTAovaEqvIIm1NvsOT3R77IVSDpHyNLPg=";
    };
  };
  "4.1.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-d48v939zfdRXk6KqyJQLsg4GBybdv/pd1swyQZlRJyc=";
    };
  };
  "4.1.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-naDBCgqcs0BLohvzm3CmTMNcRz/g7SeINJMaAxJ+7rU=";
    };
  };
  "4.1.8" = {
    npmDeps = {
      "x86_64-linux" = "sha256-5g6nB526K1VkzHGmPifxFbzk08v7W73ZbB4DG0eXOUs=";
    };
  };
  "4.1.9" = {
    npmDeps = {
      "x86_64-linux" = "sha256-3VvPLXNwhGT3n7KYhE5sBfQFYizp78l5hKbYF+H6Pok=";
    };
  };
  "4.2.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Vr56btGBi9SDK1xUSrDLA3meWyQfPZaO2Uyh1q0vzx0=";
    };
  };
  "4.2.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-5dm0Q1+5ybVx2I0XZAtw5mdXhU9+6oDZuVzEIuPD+0U=";
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
