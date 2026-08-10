final: prev: {
  # pi-llama-cpp-stats: zero-dep extension, single .ts file
  pi-llama-cpp-stats = prev.fetchurl {
    url = "https://cdn.jsdelivr.net/npm/pi-llama-cpp-stats@0.1.6/index.ts";
    hash = "sha256-XJds2Qky22Md3ZNMFlvy7sOfPYnJ3Kx5ogfKgO8dBGE=";
  };

  # pi-web-access v0.10.7: clean lockfile, no workspace deps
  pi-web-access = prev.buildNpmPackage {
    pname = "pi-web-access";
    version = "0.10.7";

    src = prev.fetchFromGitHub {
      owner = "nicobailon";
      repo = "pi-web-access";
      rev = "v0.10.7";
      hash = "sha256-D9no4SLigH/t3/WfirixMbTEjcEwZwJXld8j7pwBCew=";
    };

    npmDepsHash = "sha256-QKmgVmIvqLbqnUmKBKniT0CvNIgZWZ9mUkha0LJMMVQ=";
    dontNpmBuild = true;
  };
}
