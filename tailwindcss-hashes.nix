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
      "aarch64-linux" = "sha256-zfWht7L0TO3lz6atk/Ao9B2qDWqyQDU64rwK8Ra7yrI=";
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
      # History: re-pinned repeatedly on 2026-08-18 while the install
      # was unfrozen (V4Gu… → GbW0… → jZTjh…). Re-verified 2026-11-23
      # with the frozen lockfile under bun 1.3.13 and 1.4.4.
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
      # History: this pin flip-flopped between zovIIqJ… (botman-box
      # production), +n6zOE… and l2AwUOc… (local dev builds).
      # Re-verified 2026-11-23 with the frozen lockfile: bun 1.3.13
      # (rails-builder's pinned nixpkgs) and bun 1.4.4 (nixos-unstable)
      # both produce the values below on both arches.
      "x86_64-linux" = "sha256-xJD/NLZu1ZJ6EffNm4gig9aB+LWuRtgg18X1N4cbZTI=";
      "aarch64-linux" = "sha256-xT5uAsoiWYDOUpNyYFxwAVvYQUqthj9UawxOQIOeQto=";
    };
  };
  "4.0.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-OhPmsqRL8znT+J7qKVN39wqmd5Hu9U3EI6m86EJWdRQ=";
      "aarch64-linux" = "sha256-dtiIvZxrec0c2VIWdtAZEjDL0Kl+ujkdIvaRPPsgpSs=";
    };
  };
  "4.0.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-A+HEZUt6kQUEHTLBApBLjeauJNqBlUX6VW8s1pnGv2o=";
      "aarch64-linux" = "sha256-wK7MYT773aHs782ZmcEzB3lqzMsEI9V+vIWOuka0bIE=";
    };
  };
  "4.0.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-099jZUPUtoFDdXUt7oBGpnN7Q8/OVt0+lJJVWR/8+jg=";
      "aarch64-linux" = "sha256-DMUaCr36PGyqzGnUrLVwkS0DmAlpI5KuCcuJgprwPQk=";
    };
  };
  "4.0.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-lOLDDxfVqr1zn2MEWT20NcaAHVfynkSvfgneGFxIGqs=";
      "aarch64-linux" = "sha256-kxVMRp3Dt8rWm7YtPrUscWFGJ8Q+UMSXHUW6EvgvqzA=";
    };
  };
  "4.0.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-9ksVnD+zG7vdJcvWD4ySyav+3MCRGW1X4uXDgC4k+Mo=";
      "aarch64-linux" = "sha256-QtBzYFnAw4i7a75g9kcKYYsWZvFgpoEPiiFeIedFg1U=";
    };
  };
  "4.0.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-RVDK4xDswAfFG+oZlh8+oaQY8T3Rc9wUIIQUcHgMUTA=";
      "aarch64-linux" = "sha256-VmSzEm4goGRpeAdX4Jxw39xgzGnM2OjvsFqcFaw0fF4=";
    };
  };
  "4.0.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-uLb5dUZOLUOE+sdYMGR8L21xj+aK5Lgjhajq5TRbFYY=";
      "aarch64-linux" = "sha256-lVFXIOfaza/X3yFRbIGh5G6i+dpgu90eS5uiPMvstmc=";
    };
  };
  "4.0.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-M4wEyFEPVqljhC+95n1m6orbypQmAZ15jwozQSDV+g8=";
      "aarch64-linux" = "sha256-fcWOpNa8Bx+OvmrEeCVUlTedkMqnXqE/IuU4X7sznzI=";
    };
  };
  "4.0.16" = {
    npmDeps = {
      "x86_64-linux" = "sha256-ha+PrutmHpH+aWfM9jsEnX/sPa4ti5ezrz3xNRER0Es=";
      "aarch64-linux" = "sha256-CIzvRFc7cl0N0Yi7QrVjP4eYV9CWm0hbg0CNPUDWCyQ=";
    };
  };
  "4.0.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-hsiOley0GKuB+Y4crHrQ74bXswtfkWH5hNTQy44gwHQ=";
      "aarch64-linux" = "sha256-m7nP3EP8vsJvVnN9mRXxHmQN7gCcEZuapeOmtnxqpzM=";
    };
  };
  "4.0.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-YJEmUqUtwIo77nW4q01203cqcydfWTrWcLcXETRFthE=";
      "aarch64-linux" = "sha256-UsjxnOCzOs6vEEyE113ib8aMHFClxhWHg5Zw2IWm/vg=";
    };
  };
  "4.0.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-OsKd/BUfQrcgszZGAaedN6FDJi1wcSiRpFO1FdQ6kwg=";
      "aarch64-linux" = "sha256-XERFRnMhF3VHCsC3d2srV6UstEeJwaVlrwy/yNjSh8I=";
    };
  };
  "4.0.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-/e5J+p7GwqL6ZFMCsKCYZGsgfCbcjTJw6HckkFkZkDs=";
      "aarch64-linux" = "sha256-1yJ4vTthWOuSM23F3zW+31ij1sx3QSsy/4/HZlTrlt4=";
    };
  };
  "4.0.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-rw+6Kbu3TBo+/adAGWXeDONL4qVv3NuT5m4Fjo8+l0o=";
      "aarch64-linux" = "sha256-llkmOLXovx4+5aq9UfCb1sHJlU3HHtH19fahbwQjUWY=";
    };
  };
  "4.0.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-iKciDB7rX7sDx6ozZA4gCzAoh/2b9sAQ0iu1XhjbFrs=";
      "aarch64-linux" = "sha256-zuFYFks9+IffGhhYLwiAP/WsSycJ6zTBjYkhmwyDG5w=";
    };
  };
  "4.0.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-wmTfZ6tVXzMYtJdm7lSMlWMJA/54FO+0aWdpXPzbqig=";
      "aarch64-linux" = "sha256-SbUALotFh9AElsq3XOrAVrPXESvqKKz7tAiM3lt+Hn4=";
    };
  };
  "4.0.8" = {
    npmDeps = {
      "x86_64-linux" = "sha256-09pj5Jw+VfjlT/KAUmlvZSd4rTNCm/KDJwFj9eDWIHU=";
      "aarch64-linux" = "sha256-6RkA+feE7irYjq7shrnACQTWpD0mceQj4LmuR0OVYO4=";
    };
  };
  "4.0.9" = {
    npmDeps = {
      "x86_64-linux" = "sha256-3yv5bBoh7LZsKjYuErdVoBedtG8B1LqycO0hplIOZXw=";
      "aarch64-linux" = "sha256-GxwEu4YiARm6eqvf78+wDNQEfB5jRoKCVnNL2aTUaiY=";
    };
  };
  "4.1.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-X4tN0WRM0PZQVBKbaFKto0Fo52ywhnywS3cTNqTecD0=";
      "aarch64-linux" = "sha256-AkvFAHyGVGZ+85/YrptVXUMVgKij6CEG6upoB3AknHc=";
    };
  };
  "4.1.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-3W47oCXtt+cOkzkgMeL9fPmkLuRQagsa3WoUD3XJskc=";
      "aarch64-linux" = "sha256-UsUNhJYSqtdMYXX6GlbIW7KbHpS3u23/OtSmg0kTjYo=";
    };
  };
  "4.1.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-6ihNmWOoMsCE2QXoOwMFa1AxT7ncRgfz3x2/ZypNU8g=";
      "aarch64-linux" = "sha256-8boJffzwnP4xEnJEak4jChK6BOJOkCctGACp9CeaNX8=";
    };
  };
  "4.1.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-RimvtyiIXaQGF0p0rCcuoSIkKnj8fifx7qebtfCh75s=";
      "aarch64-linux" = "sha256-TxE0GZ0ZYK3Ovc0xVMs13Q76NUYWTTOyvvJz2uN86uo=";
    };
  };
  "4.1.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Uaje2AEtm3+qKnmWeP3dwlvqqyDeP8x5rAST8GL5NpQ=";
      "aarch64-linux" = "sha256-TH4qoCHcdHX2MflGy98PVplLY5q9ExJ/xqob8xq62ZE=";
    };
  };
  "4.1.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-dV0ECzqSKZlJ/kSLxW4OUgt4YsUVAHFjPbBIG+rgCWE=";
      "aarch64-linux" = "sha256-ZoctWfIDQFLXnA1LeLd1IeDbXAG+AXGzSS0hDn37f14=";
    };
  };
  "4.1.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-GkAsJ2Dw8TCScJ5D+TsI0/CKwZ3oKfAO1KGbNFAOGFA=";
      "aarch64-linux" = "sha256-sNrrjc0ZqbkjzTAm+GI7Cs7jW+6ul5jJeOiurrJXGXs=";
    };
  };
  "4.1.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-kSuXfKZwj9t3D6X3LBCTbj6c2K6MdaHnnz0HD4YKGEQ=";
      "aarch64-linux" = "sha256-yb2HLDy7oWuTp/soKxzvnPCZNPuBiEXybyOAKzHa8UA=";
    };
  };
  "4.1.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-saJaGXvD/erHP2KcfQgFn3FYsJfKdUwsumCntmknfk8=";
      "aarch64-linux" = "sha256-Vc2pEXSaa/ej7Prw235+NrxYlPmubJrTtPkkDYD4zA4=";
    };
  };
  "4.1.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-mZb8c5vxYjAuoktf6QmkkcmZWSb9F+sNRWOuWs5MMZ8=";
      "aarch64-linux" = "sha256-Z/FO2VeOfGiwuwwL2OoNpdG7dlJN+P0OgpXQVc0P+OQ=";
    };
  };
  "4.1.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-/LtjhHGyM56NM1uJnsoZyoFJgAMUHv7h3PleEsSyYiE=";
      "aarch64-linux" = "sha256-5dkbicrP9/Y+CkZfUD5GzhLGhUdvQ9Y/Eu0+kl3Y4Ts=";
    };
  };
  "4.1.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-6wdGhp70f2SXtBtAibMqNsu/Dz9ksZqH4ry/P3PEveQ=";
      "aarch64-linux" = "sha256-7aSXEatHPdu1yLQAVATc+fVCIcs7jtdcunMmlLVDpRk=";
    };
  };
  "4.1.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-7RFpvcglh/hTAovaEqvIIm1NvsOT3R77IVSDpHyNLPg=";
      "aarch64-linux" = "sha256-pFwG3UeKUeR9J1Ud30todKPDnCR8huBzBxWO/zXja7E=";
    };
  };
  "4.1.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-d48v939zfdRXk6KqyJQLsg4GBybdv/pd1swyQZlRJyc=";
      "aarch64-linux" = "sha256-Bmh4J5WZDlLe7qxKbaM/eFtZmE8Miu5W/3GmSaBCOX0=";
    };
  };
  "4.1.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-naDBCgqcs0BLohvzm3CmTMNcRz/g7SeINJMaAxJ+7rU=";
      "aarch64-linux" = "sha256-+bQq6f8Q53vYcUm5PLWezvDdyyKtTpIG+rNevFWZNzg=";
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
      "x86_64-linux" = "sha256-3VvPLXNwhGT3n7KYhE5sBfQFYizp78l5hKbYF+H6Pok=";
      "aarch64-linux" = "sha256-siKREBzumqiPG0SzUbHJpuyGm0GOZFVtTBDix7kFcT0=";
    };
  };
  "4.2.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Vr56btGBi9SDK1xUSrDLA3meWyQfPZaO2Uyh1q0vzx0=";
      "aarch64-linux" = "sha256-EhQligDrNFCJsCErKMYfVbaDUlmxBXR4fSysJC5qdvg=";
    };
  };
  "4.2.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-5dm0Q1+5ybVx2I0XZAtw5mdXhU9+6oDZuVzEIuPD+0U=";
      "aarch64-linux" = "sha256-NmcGlw2kQljvjNoYgho+g1BANkwXkXRr92Pe7EfMvTo=";
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
