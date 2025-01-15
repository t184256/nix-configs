_: super:

{
  alacritty = super.alacritty.overrideAttrs (_: rec {
    version = "v0.15.0-mod";
    src = super.fetchFromGitHub {
      owner = "t184256";
      repo = "alacritty";
      rev = version;
      sha256 = "sha256-6NZG7cabDKMPKt1vz0FT7bUf9HrR1rwk061459Vo3wM=";
    };
    cargoDeps = super.rustPlatform.importCargoLock {
      lockFile = ./Cargo.lock;
      outputHashes = {
        "vte-0.13.1" = "sha256-PG9lw8ozH4VgwgUXAZ7N/lOz9x1JL2rUjZF58atSAbc=";
      };
    };
  });
}
