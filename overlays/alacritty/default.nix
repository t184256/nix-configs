_: super:

{
  alacritty = super.alacritty.overrideAttrs (_: rec {
    name = "alacritty-mod";
    version = "0.16.1";
    src = super.fetchFromGitHub {
      owner = "t184256";
      repo = "alacritty";
      rev = "v${version}-mod";
      sha256 = "sha256-UH8FD7Z15JhRlSwVlcaYz+fOayd5eWo0W3s4aDIH/CM=";
    };
    cargoDeps = super.rustPlatform.importCargoLock {
      lockFile = ./Cargo.lock;
      outputHashes = {
        "vte-0.15.0" = "sha256-1B2Sd3vDQTmw2zSSbUUyNUd1nFd1IRar5o7qe/df0B4=";
      };
    };
  });
}
