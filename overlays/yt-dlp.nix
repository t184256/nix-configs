_: prev:

let
  newerVer = "2024.12.23";
  overrides = _: {
    name = "yt-dlp-${newerVer}";
    version = newerVer;
    src = prev.fetchFromGitHub {
      owner = "yt-dlp";
      repo = "yt-dlp";
      rev = "2024.12.23";
      hash = "sha256-6zv2NqbUxirMwa6OCzeKXuqLB4sFiYAcy3TYke2jhKc=";
    };
  };
in
{
  pythonPackagesExtensions =
    prev.pythonPackagesExtensions ++ [(_: pyPrev: { yt-dlp =
      if prev.lib.versionAtLeast pyPrev.yt-dlp.version newerVer
      then pyPrev.yt-dlp
      else pyPrev.yt-dlp.overridePythonAttrs overrides;
    })];

  yt-dlp =
    if prev.lib.versionAtLeast prev.yt-dlp.version newerVer
    then prev.yt-dlp
    else prev.yt-dlp.overrideAttrs overrides;  # not the best way, loses share/
}
