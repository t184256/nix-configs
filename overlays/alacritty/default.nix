_: super:

{
  alacritty = super.alacritty.overrideAttrs (oa: rec {
    version = "0.13.1-master-t184256-altfont";
    src = super.fetchFromGitHub {
      owner = "t184256";
      repo = "alacritty";
      rev = "7ae7b5e7969f66440c959cdef4812b9b98fc47d9";
      sha256 = "sha256-feGUWXcIO62PBnn9fU0mZs7vfUmEVuzsz39TxsJKdH8=";
    };
    cargoDeps = super.rustPlatform.importCargoLock {
      lockFile = ./Cargo.lock;
      outputHashes = {
        "vte-0.13.0" = "sha256-qzk1+cqJrc6SNXcAQEgJgjPlDu9sEmS13CcRK7jEXvs=";
      };
    };
  });
}
