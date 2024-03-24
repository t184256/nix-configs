_: super:

{
  alacritty = super.alacritty.overrideAttrs (_: {
    version = "0.13.1-master-2024-03-24-t184256-altfont";
    src = super.fetchFromGitHub {
      owner = "t184256";
      repo = "alacritty";
      rev = "5744f32e7d845ca1aeb18daa34d867efc2fc3f6b";
      sha256 = "0pygrzpknvsxdxjfiq4krv58x9y72zfwr65d81b1x2vqnszgi8hf";
    };
    cargoDeps = super.rustPlatform.importCargoLock {
      lockFile = ./Cargo.lock;
      outputHashes = {
        "vte-0.13.0" = "sha256-qzk1+cqJrc6SNXcAQEgJgjPlDu9sEmS13CcRK7jEXvs=";
      };
    };
  });
}
