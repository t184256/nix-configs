final: prev:
# Doesn't work with non-default python version

let
  newerVer = "2025.03.31";
  overrides-fresh = _: {
    name = "yt-dlp-${newerVer}";
    version = newerVer;
    src = prev.fetchFromGitHub {
      owner = "yt-dlp";
      repo = "yt-dlp";
      rev = newerVer;
      hash = "sha256-csw91VbzY9IursMQFGwnlobZI3U6QOBDo31oq+X0ETI=";
    };
  };
  overrides-plugins = oa: {
    propagatedBuildInputs = (oa.propagatedBuildInputs or []) ++ [
      yt-dlp-get-pot
      bgutil-ytdlp-pot-provider
    ];
  };
  overrides-fresh-plugins = oa: (overrides-fresh oa) // (overrides-plugins oa);
  yt-dlp = prev.yt-dlp.overridePythonAttrs (
    if prev.lib.versionAtLeast prev.yt-dlp.version newerVer
    then overrides-plugins
    else overrides-fresh-plugins
  );
  yt-dlp-get-pot = prev.python3Packages.buildPythonPackage rec {
    pname = "yt-dlp-get-pot";
    version = "0.3.0";
    pyproject = true;
    src = prev.fetchFromGitHub {
      owner = "coletdjnz";
      repo = "yt-dlp-get-pot";
      rev = "v${version}";
      hash = "sha256-MtQFXWJByo/gyftMtywCCfpf8JtldA2vQP8dnpLEl7U=";
    };
    build-system = [ prev.python3Packages.hatchling ];
    doCheck = false;
    pythonImportsCheck = [ "yt_dlp_plugins" ];
  };
  bgutil-ytdlp-pot-provider = prev.python3Packages.buildPythonPackage rec {
    pname = "bgutil-ytdlp-pot-provider";
    version = "0.8.2";
    pyproject = true;
    src = prev.fetchFromGitHub {
      owner = "Brainicism";
      repo = "bgutil-ytdlp-pot-provider";
      rev = version;
      hash = "sha256-u34RkPmNr0yC2PH8GWF24T+uwCsrVQmg9/qfE3YJQHw=";
    };
    propagatedBuildInputs = [ yt-dlp-get-pot ];
    postUnpack = "pwd; ls; cp source/README.md source/plugin/";
    sourceRoot = "source/plugin";
    build-system = [ prev.python3Packages.hatchling ];
    doCheck = false;
    pythonImportsCheck = [ "yt_dlp_plugins" ];
  };
in
{
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (_: pyPrev: {
        yt-dlp = pyPrev.toPythonModule yt-dlp;
        #yt-dlp = builtins.trace yt-dlp pyPrev.toPythonModule (yt-dlp.override {
        #  python3Packages = pyFinal;
        #});
    })
  ];

  inherit yt-dlp;
}
