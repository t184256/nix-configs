_: super:

{
  alacritty = super.alacritty.overrideAttrs (_: {
    version = "0.13.2-master-2024-08-11-t184256-altfont";
    src = super.fetchFromGitHub {
      owner = "t184256";
      repo = "alacritty";
      rev = "003270d093b6cc3c8bdeb8ac85316c478daffa1d";
      sha256 = "sha256-N/DyfR4drHxjwGGi14mHCee+kRS3o0qQlkfQaZg2wBk=";
    };
    cargoDeps = super.rustPlatform.importCargoLock {
      lockFile = ./Cargo.lock;
      outputHashes = {
        "vte-0.13.0" = "sha256-/9ZTANaciyxg5Y7nHsB3Hcg4y6clxeV0ahyPXtRiXwg=";
      };
    };
  });
}
