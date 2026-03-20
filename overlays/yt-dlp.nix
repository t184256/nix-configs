final: prev:
# Doesn't work with non-default python version

let
  newerVer = "2026.03.17";
  overrides-fresh = _: {
    name = "yt-dlp-${newerVer}";
    version = newerVer;
    src = prev.fetchFromGitHub {
      owner = "yt-dlp";
      repo = "yt-dlp";
      rev = newerVer;
      hash = "sha256-A4LUCuKCjpVAOJ8jNoYaC3mRCiKH0/wtcsle0YfZyTA=";
    };
    ### !!! remove
    postPatch = ''
      substituteInPlace yt_dlp/version.py \
        --replace-fail "UPDATE_HINT = None" 'UPDATE_HINT = "Nixpkgs/NixOS likely already contain an updated version.\n       To get it run nix-channel --update or nix flake update in your config directory."'
        # deno is required for full YouTube support (since 2025.11.12).
        # This makes yt-dlp find deno even if it is used as a python dependency, i.e. in kodiPackages.sendtokodi.
        # Crafted so people can replace deno with one of the other JS runtimes.
        substituteInPlace yt_dlp/utils/_jsruntime.py \
          --replace-fail "path = _determine_runtime_path(self._path, '${final.deno.meta.mainProgram}')" "path = '${prev.lib.getExe final.deno}'"
    '';
    ### !!! remove
  };
  overrides-plugins = oa: {
    propagatedBuildInputs = (oa.propagatedBuildInputs or []) ++ [
      bgutil-ytdlp-pot-provider
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
    version = "1.3.0";
    pyproject = true;
    src = prev.fetchFromGitHub {
      owner = "Brainicism";
      repo = "bgutil-ytdlp-pot-provider";
      rev = version;
      hash = "sha256-WPLNjfVYDbPsEMVhjuF3dVarahdIKT7pt518SePfB8A=";
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
