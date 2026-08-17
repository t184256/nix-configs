# @ribbons-digital/pi-advisor v0.3.0: automatic async secondary review
final: prev: {
  pi-advisor = prev.buildNpmPackage {
    pname = "pi-advisor";
    version = "0.3.0";

    src = prev.fetchurl {
      url = "https://registry.npmjs.org/@ribbons-digital/pi-advisor/-/pi-advisor-0.3.0.tgz";
      sha1 = "a49e9368c9c8f9cf00b71623285930ad5e075991";
    };

    patches = [ ./compact-advice-card.patch ];

    # Author didn't ship a lockfile; vendor one
    postPatch = ''
      cp ${./package-lock.json} package-lock.json
    '';

    npmDepsHash = "sha256-K0P/Z1FYcf1ANtRTP3qyPARm7ifcmKt0ZPajsiNwYxA=";
    npmDepsFetcherVersion = 2;
    dontNpmBuild = true;
  };
}
