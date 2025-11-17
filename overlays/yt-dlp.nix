final: prev:
# Doesn't work with non-default python version

let
  newerVer = "2025.11.12";
  overrides-fresh = _: {
    name = "yt-dlp-${newerVer}";
    version = newerVer;
    src = prev.fetchFromGitHub {
      owner = "yt-dlp";
      repo = "yt-dlp";
      rev = newerVer;
      hash = "sha256-Em8FLcCizSfvucg+KPuJyhFZ5MJ8STTjSpqaTD5xeKI=";
    };
  };
  overrides-plugins = oa: {
    propagatedBuildInputs = (oa.propagatedBuildInputs or []) ++ [
      bgutil-ytdlp-pot-provider
      final.deno
    ];
  };
  overrides-fresh-plugins = oa: (overrides-fresh oa) // (overrides-plugins oa);
  yt-dlp = prev.yt-dlp.overridePythonAttrs (
    if prev.lib.versionAtLeast prev.yt-dlp.version newerVer
    then overrides-plugins
    else overrides-fresh-plugins
  );
  bgutil-ytdlp-pot-provider = prev.python3Packages.buildPythonPackage rec {
    pname = "bgutil-ytdlp-pot-provider";
    version = "1.2.2";
    pyproject = true;
    src = prev.fetchFromGitHub {
      owner = "Brainicism";
      repo = "bgutil-ytdlp-pot-provider";
      rev = version;
      hash = "sha256-KKImGxFGjClM2wAk/L8nwauOkM/gEwRVMZhTP62ETqY=";
    };
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
        inherit bgutil-ytdlp-pot-provider;
    })
  ];

  inherit yt-dlp;
}
