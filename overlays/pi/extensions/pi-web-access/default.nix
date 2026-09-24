final: prev: {
  pi-web-access = prev.buildNpmPackage {
    pname = "pi-web-access";
    version = "0.31.0";

    src = prev.fetchFromGitHub {
      owner = "nicobailon";
      repo = "pi-web-access";
      rev = "v0.31.0";
      hash = "sha256-ykR2slh8MkxxbP660h0rvk2Y7SaKv+Cw/lJC21JqGW8=";
    };

    patches = [ ./lockfile.patch ];

    # fetcher v1 misses the nested @earendil-works entries in the lockfile
    npmDepsFetcherVersion = 2;
    npmDepsHash = "sha256-NiBtIPIYbL+36L5SuBAm1yJk86WON4FLtPGz1A/qdsY=";
    dontNpmBuild = true;
  };
}
