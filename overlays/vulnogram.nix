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
    url = "https://cdnjs.cloudflare.com/ajax/libs/ace/1.45.2/ace.js";
    sha256 = "aQB8sOtkLp0/hcEtdK8v1Bndh39H4HMpk7yo76IueAw=";
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
    nativeBuildInputs = [ prev.python3 prev.xdg-utils ];

    installPhase = ''
      # fix copying multiple lines out of the editor
      substituteInPlace js/vg-editor.js \
        --replace-fail 'editorUnloadWarningDisabled=!1;' \
        'editorUnloadWarningDisabled=!1;
      document.addEventListener("copy", function (e) {
          if (!sourceEditor || !sourceEditor.container.contains(e.target))
            return;
          var text = sourceEditor.getCopyText();
          if (!text || !e.clipboardData || !e.clipboardData.setData) return;
          e.preventDefault();
          e.clipboardData.setData("text/plain", text);
      }, true);'

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
      cat > $out/bin/vulnogram-dumb <<EOF
      #!${prev.bash}/bin/bash
      # needs security.fileuri.strict_origin_policy = false in firefox
      exec ${prev.xdg-utils}/bin/xdg-open "$out/share/vulnogram/index.html"
      EOF
      chmod +x $out/bin/vulnogram-dumb

      cat > $out/bin/vulnogram-server <<EOF
      #!${prev.bash}/bin/bash
      ${prev.python3}/bin/python3 -m http.server --bind 127.0.0.1 8334 \
        --directory "$out/share/vulnogram" &
      sleep .25
      ${prev.xdg-utils}/bin/xdg-open http://127.0.0.1:8334/
      wait
      EOF
      chmod +x $out/bin/vulnogram-server
    '';
  };
}
