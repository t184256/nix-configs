self: super:

{
  noto-fonts-extracondensed = super.stdenv.mkDerivation {
    name = "noto-fonts-extracondensed";
    version = super.noto-fonts.version;
    buildInputs = [ super.noto-fonts-extra ];

    phases = [ "installPhase" ];

    installPhase = ''
      mkdir -p $out/share/fonts/truetype/noto/
      cp -va ${super.noto-fonts-extra}/share/fonts/truetype/noto/Noto*ExtraCondensed*.ttf \
             $out/share/fonts/truetype/noto
    '';
  };
}
