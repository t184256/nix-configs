_: super:

{
  alacritty = super.alacritty.overrideAttrs (_: {
    version = "0.13.2-master-2024-05-03-t184256-altfont";
    src = super.fetchFromGitHub {
      owner = "t184256";
      repo = "alacritty";
      rev = "4c1504423d9ef48d5ae31ba683a536e91495d24a";
      sha256 = "0rjxhq3w99wn89rwh133f0s2h5fbmxd6m04205j5w2v83fikgs0r";
    };
    cargoDeps = super.rustPlatform.importCargoLock {
      lockFile = ./Cargo.lock;
      outputHashes = {
        "vte-0.13.0" = "sha256-qzk1+cqJrc6SNXcAQEgJgjPlDu9sEmS13CcRK7jEXvs=";
      };
    };
  });
}
