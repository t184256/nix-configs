self: super:

{
  noto-fonts-extracondensed = super.stdenvNoCC.mkDerivation {
    name = "noto-fonts-extracondensed";
    inherit (super.noto-fonts) version src;

    installPhase = ''
      mkdir -p $out/share/fonts/noto/
      find
      cp -va fonts/NotoSans/unhinted/*/NotoSans-ExtraCondensed* \
             $out/share/fonts/noto/
      cp -va fonts/NotoSerif/unhinted/*/NotoSerif-ExtraCondensed* \
             $out/share/fonts/noto/
    '';
  };
}
