_: super:

{
  direnv = super.direnv.overrideAttrs (oa: {
    patches = super.fetchpatch {
      url = "https://github.com/tjcrone/direnv/commit/39856b6c266392aac08cdc25eb7f0c88b851fd1b.patch";
      sha256 = "sha256-jL6G7aTNpbnJ5eKd0/jOJY4LcvWxiSTnCfWCuHZnRW0=";
    };
  });
}
