final: prev: {
  pi-web-access = prev.buildNpmPackage {
    pname = "pi-web-access";
    version = "0.47.0";

    src = prev.fetchFromGitHub {
      owner = "nicobailon";
      repo = "pi-web-access";
      rev = "v0.47.0";
      hash = "sha256-QfwEKSqOTc/VhPonFySNsgDAOkx9ROf+PnEF9v/iCow=";
    };

    # fetcher v1 misses the nested @earendil-works entries in the lockfile
    npmDepsFetcherVersion = 2;
    npmDepsHash = "sha256-zceAHKLRFpT+RYcYo199+lf2+0Ly/DXtcB/U/QW7+m0=";
    dontNpmBuild = true;
  };
}
