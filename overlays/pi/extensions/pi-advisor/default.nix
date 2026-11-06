# philipbrembeck/pi-advisor v0.14.4: automatic async secondary review
final: prev: {
  pi-advisor = prev.stdenv.mkDerivation {
    pname = "pi-advisor";
    version = "0.14.4";

    src = prev.fetchFromGitHub {
      owner = "philipbrembeck";
      repo = "pi-advisor";
      rev = "v0.14.4";
      sha256 = "sha256-0IMUnODkWUBvlwDaaGZfT+sYR9vNKFxLlKVd5pNqiHU=";
    };

    patches = [
      ./compact-advice-card.patch
      ./do-not-force-model.patch
      ./do-not-write-config.patch
    ];

    # no runtime deps, no buildNpmPackage, install by copying
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/lib/node_modules/pi-advisor-flow
      cp -r dist extensions package.json CHANGELOG.md LICENSE README.md \
        $out/lib/node_modules/pi-advisor-flow/
    '';
  };
}
