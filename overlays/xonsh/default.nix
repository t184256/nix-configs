self: super:

let
  xontribs = builtins.mapAttrs (_: f: (f { pkgs = super; }))
                               ((import ../../.autoimport).asAttrs ./xontribs);
  # avoids https://github.com/xonsh/xonsh/issues/3810
  patched-ptk = super.python3Packages.prompt-toolkit.overridePythonAttrs ({
    patches = [
      (super.fetchpatch {
        url = "https://github.com/prompt-toolkit/python-prompt-toolkit/commit/e5a86e270e7ee698c849d39196d5a6a0d6e5a331.patch";
        sha256 = "sha256-KbM1FECVs+6MKyvEOTzyfR5s825ejunr4q2blJXOmJ0=";
      })
    ];
    patchFlags = [ "-p1" ];
    doCheck = false;
  });

  xonshLib = super.python3Packages.buildPythonPackage rec {
    propagatedBuildInputs = with super.python3Packages; [ ply pygments ]
                             ++ [ patched-ptk ];
    inherit (super.xonsh)
                          pname
                          version
                          src
                          LC_ALL
                          postPatch
                          disabledTests
                          #disabledTestPaths
                          #nativeCheckInputs
                          preCheck
                          meta shellPath;

    #can't inherit these

    disabledTestPaths = [
      # fails on sandbox
      "tests/completers/test_command_completers.py"
      "tests/test_ptk_highlight.py"
      "tests/test_ptk_shell.py"
      # fails on non-interactive shells
      "tests/prompt/test_gitstatus.py"
      "tests/completers/test_bash_completer.py"
    ];

    nativeCheckInputs = (with super; [ glibcLocales git ]) ++
                        (with super.python3Packages; [
                          pyte pytestCheckHook pytest-mock pytest-subprocess
                        ]);
  };

  makeXonshEnv = { extras }: super.python3.buildEnv.override {
      extraLibs = [ self.xonshLib ] ++ extras;
  };

  makeXonshWrapper = args: super.writeShellScriptBin "xonsh" ''
    exec ${makeXonshEnv args}/bin/python3 -u -m xonsh "$@"
  '';

  makeCustomizableXonsh = args:
    let
      this = (makeXonshWrapper args) // args;
    in
    this // rec {
      customize = a: makeCustomizableXonsh (args // a);
      withExtras = e: customize { extras = this.extras ++ e; };
      withXontribs = f: withExtras (f xontribs);
      withPythonPackages = f: withExtras (f super.python3Packages);
    };

  xonsh = makeCustomizableXonsh { extras = []; };
in
{
  inherit xonsh xontribs xonshLib;
}
