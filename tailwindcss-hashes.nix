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
      "x86_64-linux" = "sha256-yOFSp9UN0MnzOyt924lVgv03VW6UkmsGGzKw+CO8oww=";
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
      "x86_64-linux" = "sha256-m+7EjRIievc7YgLSe3gFzP4AAB4d29gEHeW/0gOSO5s=";
    };
  };
  "4.0.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-GeZRTPLWVnlMSTSr4DvkjeMeiHMN/tGXBnxuCyP2ldo=";
    };
  };
  "4.0.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-RJURXU7WX1KYkw0qD2Fk38OOpRCuBEd4cNpdtYh75GI=";
    };
  };
  "4.0.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-7dT20D59WSeZfgAiIapd5p63T9HwrbGDxy0G9qYgxjI=";
    };
  };
  "4.0.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-2fnwYXzXYzzdOQrZ03GXKAEtxlu9RMLFn+KJLIqVjB4=";
    };
  };
  "4.0.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-hs6ogsW+pHnXabPonozZQ80wJgH8CxT1O8Zcn1XZb/Y=";
    };
  };
  "4.0.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Grfy9esYPqHc42BQtxz0IMSHQSq0ac1+FSBq1Xvc5b8=";
    };
  };
  "4.0.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-1Pn43rzXmufKbUlTWXM+Fvr2Dd2sBKbWUUM9NUwDJ88=";
    };
  };
  "4.0.16" = {
    npmDeps = {
      "x86_64-linux" = "sha256-9EsM0rKexRH91a0yaB2IcFdfJ9c9cY+0jCKDj1xwjA8=";
    };
  };
  "4.0.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-qNzm0jiM0ZXsWy35D/qL3ZZhzGq3ZeIXB1a60jCDTO8=";
    };
  };
  "4.0.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-R2SeZFVN0pnuSbWM1OSGidwReToE6uGq16PkryOwcJU=";
    };
  };
  "4.0.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-8xlONXOQr/9AaS40DElBkembsQQaZgQk7ncy06OzVNo=";
    };
  };
  "4.0.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-owlvIxGHL9nqrbx41uQqeS+fXjmVdZaYiE0zugEq40c=";
    };
  };
  "4.0.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-OqzKwiTsBp2DL9VLxYmspuk1NNsIQs477RlStq9iRFA=";
    };
  };
  "4.0.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-2F3jG0Yl73TUCRuvc0iFSUH3hGJ6hMdwDo+LuJCKafA=";
    };
  };
  "4.0.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-fkuTRogimIYo3bo/g6HHw16rvCmdi9+80+RnzbGSz14=";
    };
  };
  "4.0.8" = {
    npmDeps = {
      "x86_64-linux" = "sha256-j2K8AYSl1LZUcWSoNv2yaYYyqpvJdAxeikGJ8WEToNg=";
    };
  };
  "4.0.9" = {
    npmDeps = {
      "x86_64-linux" = "sha256-onAX9nnIq3P7KrVNPc+rc56JNnkN9HXV3txE3hT75ZY=";
    };
  };
  "4.1.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-6aoPe3invfsNoeXgbS3QeGE7dq8irS6ljVCniKU3MhQ=";
    };
  };
  "4.1.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-e4uteRoOlYtub0Oz4m7whYfR+VzzQmUBq889Lw9nSZA=";
    };
  };
  "4.1.10" = {
    npmDeps = {
      "x86_64-linux" = "sha256-cYoTUd/QO0lu6ucy1qtUkiVEAelE6O/DKskDM/0pY8Q=";
    };
  };
  "4.1.11" = {
    npmDeps = {
      "x86_64-linux" = "sha256-s7H+KB6lm6DeA6TfCGlga5mcyNzCFHXr2CYvU6h/KYM=";
    };
  };
  "4.1.12" = {
    npmDeps = {
      "x86_64-linux" = "sha256-v9+3q7kYD7Ugu8TMf9sb0JUkhtJoYOXBOS/6f677yIc=";
    };
  };
  "4.1.13" = {
    npmDeps = {
      "x86_64-linux" = "sha256-SKqos8McRJGMbOl6gbbVjA8XkMf2dVYy8yT/UN01X8g=";
    };
  };
  "4.1.14" = {
    npmDeps = {
      "x86_64-linux" = "sha256-k8OKGVmIv7UMqWCEp9caAwKJlcfxRscNPcY1mrISKWY=";
    };
  };
  "4.1.15" = {
    npmDeps = {
      "x86_64-linux" = "sha256-QR6DoAwH2e/YQbxoCAt8ErfFZuOnvO4rNOzfiQaaRos=";
    };
  };
  "4.1.17" = {
    npmDeps = {
      "x86_64-linux" = "sha256-Xy3Lk1gzSei6buc1U2NIO55hXS+womzkpJq81NeOed0=";
    };
  };
  "4.1.2" = {
    npmDeps = {
      "x86_64-linux" = "sha256-St97wLZQvJPyQr+bc2bayRYfQWMy20bhosFa9pNC5wg=";
    };
  };
  "4.1.3" = {
    npmDeps = {
      "x86_64-linux" = "sha256-7w3PHb96N3E9d4RaT4PVBLNzgFpLT6J9WC9bzBBDL2U=";
    };
  };
  "4.1.4" = {
    npmDeps = {
      "x86_64-linux" = "sha256-t/pIY/v6VsXl+ZsYVGmV8TL9rWrG9pXzIZcqtZspBbw=";
    };
  };
  "4.1.5" = {
    npmDeps = {
      "x86_64-linux" = "sha256-6oJNphjwaMygMg5Ju0gpkxpqdgS+O64SyE2KoH5e+9c=";
    };
  };
  "4.1.6" = {
    npmDeps = {
      "x86_64-linux" = "sha256-4bXgv+D+UfxwDjv3roTPP2CgnayeGCzIl7MNHIwO+dI=";
    };
  };
  "4.1.7" = {
    npmDeps = {
      "x86_64-linux" = "sha256-AKlEWFEgEYa1hrziGBn6t/7cm9yehr7zCDiLVzibIOY=";
    };
  };
  "4.1.8" = {
    npmDeps = {
      "x86_64-linux" = "sha256-5g6nB526K1VkzHGmPifxFbzk08v7W73ZbB4DG0eXOUs=";
    };
  };
  "4.1.9" = {
    npmDeps = {
      "x86_64-linux" = "sha256-XKmPTuluQhZVjsY5eGJBclevLr4Ff0CDuMue9cOR6uk=";
    };
  };
  "4.2.0" = {
    npmDeps = {
      "x86_64-linux" = "sha256-lNOw7p9TuCU7uIDZyCTxXhcm+1++d0UqF9lv0BYsBJQ=";
    };
  };
  "4.2.1" = {
    npmDeps = {
      "x86_64-linux" = "sha256-q67x05vX/l3liJ2M3DQteUY0dBHKVZmLjwB4JEwmttE=";
    };
  };
}
