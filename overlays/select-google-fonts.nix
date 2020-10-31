self: super:

let
  fonts = super.lib.groupBy (fname: builtins.head (builtins.split "-" fname))
                            (builtins.attrNames (builtins.readDir (
                              super.google-fonts.outPath +
                              "/share/fonts/truetype"
                            )));

  makePaths = fnames: builtins.concatStringsSep " " (
    map (fname: "${super.google-fonts}/share/fonts/truetype/${fname}") fnames
  );

  makePathsMultifont = fonts: builtins.concatStringsSep " " (
    map makePaths (builtins.attrValues fonts)
  );

  subset = pkgName: filterFunction:
    let
      filteredFonts = super.lib.filterAttrs (
        fontName: _: filterFunction fontName
      ) fonts;
    in
    super.stdenv.mkDerivation {
      name = pkgName;
      version = super.google-fonts.version;
      buildInputs = [ super.google-fonts ];

      phases = [ "installPhase" ];

      installPhase = ''
        mkdir -p $out/share/fonts/truetype/
        cp -va ${makePathsMultifont filteredFonts} $out/share/fonts/truetype/
      '';
  };

  specific = name: subset "google-font-just-${name}" (n: n == name);

  separate = builtins.mapAttrs (name: _: specific name) fonts;
in
{
  google-fonts = super.google-fonts // {
    subset = subset;      # (google-fonts.subset pkgName filterFunction)
    specific = specific;  # (google-fonts.specific "RobotoCondensed")
    just = separate;      # google-fonts.just.RobotoCondensed
  };
}
