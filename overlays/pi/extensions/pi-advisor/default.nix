# philipbrembeck/pi-advisor v0.13.1: automatic async secondary review
final: prev: {
  pi-advisor = prev.stdenv.mkDerivation {
    pname = "pi-advisor";
    version = "0.13.1";

    src = prev.fetchFromGitHub {
      owner = "philipbrembeck";
      repo = "pi-advisor";
      rev = "v0.13.1";
      sha256 = "sha256-AvTxZ7UVa6XXS+9O/flAq85v7ZunXDArWnx62VJC2Gw=";
    };

    patches = [ ./compact-advice-card.patch ];

    # no runtime deps, no buildNpmPackage, install by copying
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/lib/node_modules/pi-advisor-flow
      cp -r dist extensions package.json CHANGELOG.md LICENSE README.md \
        $out/lib/node_modules/pi-advisor-flow/
    '';
  };
}
