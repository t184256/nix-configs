_: super:

{
  yt-dlp =
    if super.lib.versionAtLeast super.akkoma.version "2024.08.01"
      then super.yt-dlp
      else super.yt-dlp.overrideAttrs (_: rec {
        version = "2024.08.01";
        src = super.fetchFromGitHub {
          owner = "yt-dlp";
          repo = "yt-dlp";
          rev = "${version}";
          hash = "sha256-u069kH4DsOLwSC7DrXkS0pOSmaYDHd9EwsH/6FirBZI=";
        };
      });
}
