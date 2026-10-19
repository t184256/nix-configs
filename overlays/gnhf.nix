_: prev:

{
  gnhf = prev.buildNpmPackage rec {
    pname = "gnhf";
    version = "0.1.51";

    src = prev.fetchFromGitHub {
      owner = "kunchenguid";
      repo = "gnhf";
      tag = "gnhf-v${version}";
      hash = "sha256-O05eS+KNxNcjHqq0G1/uT1hOfLHBpEK3f0XHigVoZts=";
    };

    npmDeps = null;
    pnpmDeps = prev.fetchPnpmDeps {
      inherit pname version src;
      inherit (prev) pnpm;
      fetcherVersion = 4;
      hash = "sha256-dmQ7bJi4L4ME0imJp9hkkkkITzQksgKdJ2d08SIrMYY=";
    };
    nativeBuildInputs = with prev; [ pnpm ];
    npmConfigHook = prev.pnpmConfigHook;
    dontNpmPrune = true;
  };
}
