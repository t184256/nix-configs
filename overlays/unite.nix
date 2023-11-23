_: super:
rec {
  gnomeExtensions = super.gnomeExtensions // {
    unite = super.stdenv.mkDerivation rec {
      pname = "unite";
      version = "77";

      src = super.fetchFromGitHub {
        owner = "hardpixel";
        repo = "unite-shell";
        rev = "v77";
        hash = "sha256-5PClGWOxqwTVaqBySu5I+qavaV1vcKHUvoYJ3Qgcq2o=";
      };

      installPhase = ''
        mkdir -p $out/share/gnome-shell/extensions
        cp -ra unite@hardpixel.eu $out/share/gnome-shell/extensions/
      '';

      passthru = {
        extensionUuid = "unite@hardpixel.eu";
        extensionPortalSlug = "unite";
      };
    };
  };
}
