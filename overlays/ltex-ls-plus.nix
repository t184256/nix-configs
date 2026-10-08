_: super:

rec {
  ltex-ls-plus = super.stdenvNoCC.mkDerivation rec {
    pname = "ltex-ls-plus";
    version = "18.7.0";
    src = super.fetchurl {
      url = "https://github.com/ltex-plus/ltex-ls-plus/releases/download/${version}/ltex-ls-plus-${version}.tar.gz";
      sha256 = "sha256-z15a7ilSVw43QMB4YO8qQ8mS6GkxQkaZhdMrIYh6xlg=";
    };
    nativeBuildInputs = [ super.makeBinaryWrapper ];
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -rfv bin/ lib/ $out
      rm -fv $out/bin/.lsp-cli.json $out/bin/*.bat
      for file in $out/bin/{ltex-ls-plus,ltex-cli-plus}; do
        wrapProgram $file --set JAVA_HOME "${super.jre_headless}"
      done
      runHook postInstall
    '';
  };
  ltex-ls = super.stdenvNoCC.mkDerivation {
    pname = "ltex-ls-actually-plus";
    version = "18.7.0";
    phases = [ "installPhase" ];
    installPhase = ''
      mkdir -p $out/bin
      ln -s ${ltex-ls-plus}/bin/ltex-ls-plus $out/bin/ltex-ls
      ln -s ${ltex-ls-plus}/bin/ltex-cli-plus $out/bin/ltex-cli
    '';
  };
}
