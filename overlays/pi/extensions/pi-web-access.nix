final: prev: {
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
