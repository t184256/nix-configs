final: prev: {
  pi-web-access = prev.buildNpmPackage {
    pname = "pi-web-access";
    version = "0.37.0";

    src = prev.fetchFromGitHub {
      owner = "nicobailon";
      repo = "pi-web-access";
      rev = "v0.37.0";
      hash = "sha256-iD8q2t6OdbVmV7BKaKn8EhNqCeMnv25WyZNuVOEI9bw=";
    };

    # fetcher v1 misses the nested @earendil-works entries in the lockfile
    npmDepsFetcherVersion = 2;
    npmDepsHash = "sha256-RXW3ymqoqq6AnYqmfhgPrMhwB/6jYmaFQdT196vKvf4=";
    dontNpmBuild = true;
  };
}
