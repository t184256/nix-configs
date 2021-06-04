self: super:

let
  subset = pkgName: prefix:
    super.stdenv.mkDerivation {
      name = pkgName;
      version = "0";
      buildInputs = [ super.google-fonts ];

      phases = [ "installPhase" ];

      installPhase = ''
        mkdir -p $out/share/fonts/truetype/
        cp -va ${super.google-fonts}/share/fonts/truetype/${prefix}-* \
               $out/share/fonts/truetype/
      '';
  };
in
{
  google-fonts = super.google-fonts // {
    # (google-fonts.just "RobotoCondensed")
    just = name: subset "google-font-just-${name}" name;
  };
}
