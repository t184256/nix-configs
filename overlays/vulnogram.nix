# Vulnogram solo CVE editor, local edition, phone home less.

_: prev:

let
  site = prev.fetchFromGitHub {
    owner = "Vulnogram";
    repo = "Vulnogram.github.io";
    rev = "5053790432c60ee515b0742eaa0665a896a5dc5b";
    hash = "sha256-936syxXdRO0mFZRtKARGidK4p+Yhu0YfFx3f2QqZcm0=";
  };

  ace = prev.fetchurl {
    url = "https://cdnjs.cloudflare.com/ajax/libs/ace/1.4.13/ace.js";
    sha256 = "bS3VAQePcKYmsvI+8BdG2QJAVb9FbiZLgM5vK2/+TcM=";
  };

  jsoneditor = prev.fetchurl {
    url =
      "https://cdnjs.cloudflare.com/ajax/libs/json-editor/2.15.2/jsoneditor.js";
    sha256 = "pGjJyrWKWdURCzLyHPSE6UWgfUKi0PeYV2mq8U0JHQA=";
  };
in
{
  vulnogram = prev.stdenvNoCC.mkDerivation {
    pname = "vulnogram";
    version = "1.0.5";
    src = site;

    installPhase = ''
      mkdir -p $out/share/vulnogram
      cp index.html cvss.html cvss4.html $out/share/vulnogram/
      cp -r css js static $out/share/vulnogram/

      cp ${ace} $out/share/vulnogram/js/ace.js
      cp ${jsoneditor} $out/share/vulnogram/js/jsoneditor.js
      substituteInPlace $out/share/vulnogram/index.html \
        $out/share/vulnogram/cvss4.html \
        --replace-fail \
          'https://cdnjs.cloudflare.com/ajax/libs/ace/1.4.13/ace.js' \
          './js/ace.js' \
        --replace-fail \
          'https://cdnjs.cloudflare.com/ajax/libs/json-editor/2.15.2/jsoneditor.js' \
          './js/jsoneditor.js'

      echo 'window.cna = {};' > $out/share/vulnogram/js/cna.js
      substituteInPlace $out/share/vulnogram/index.html \
        --replace-fail 'https://vulnogram.org/seaview/cna.js' './js/cna.js' \
        --replace-fail 'vulnogram.org/seaview/cna.js' './js/cna.js'

      if grep -Eq "(cdnjs|seaview.cna)" -R $out; then exit 1; fi

      mkdir -p $out/bin
      cat > $out/bin/vulnogram <<EOF
      #!${prev.bash}/bin/bash
      exec ${prev.xdg-utils}/bin/xdg-open "$out/share/vulnogram/index.html"
      EOF
      chmod +x $out/bin/vulnogram
    '';
  };
}
