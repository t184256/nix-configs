_: super:

{
  alacritty = super.alacritty.overrideAttrs (_: rec {
    version = "v0.14.0-rc1-mod";
    src = super.fetchFromGitHub {
      owner = "t184256";
      repo = "alacritty";
      rev = version;
      sha256 = "sha256-FTR4t+bLTPUXNoU6TWnaSChXd4QNtWZA08G5EcbHA6I=";
    };
    cargoDeps = super.rustPlatform.importCargoLock {
      lockFile = ./Cargo.lock;
      outputHashes = {
        "vte-0.13.0" = "sha256-/9ZTANaciyxg5Y7nHsB3Hcg4y6clxeV0ahyPXtRiXwg=";
      };
    };
  });
}
