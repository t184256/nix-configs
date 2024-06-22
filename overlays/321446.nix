# https://github.com/NixOS/nixpkgs/pull/321446
final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (
      python-final: python-prev: {
        pymilter = python-prev.pymilter.overridePythonAttrs (_: rec {
          pname = "pymilter";
          version = "1.0.6";
          src = prev.fetchFromGitHub {
            owner = "sdgathman";
            repo = pname;
            rev = "${pname}-${version}";
            sha256 = "sha256-plaWXwDAIsVzEtrabZuZj7T4WNfz2ntQHgcMCVf5S70=";
          };
          propagatedBuildInputs = with python-prev; [ pydns berkeleydb ];
          patches = [];
        });
      }
    )
  ];
}
