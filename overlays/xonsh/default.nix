self: super:

let
  xontribs = builtins.mapAttrs (_: f: (f { pkgs = super; }))
                               ((import ../../.autoimport).asAttrs ./xontribs);

  # TODO: use upstream-wrapped xonsh instead of my contraption
  xonshLib = super.python3Packages.buildPythonPackage rec {
    propagatedBuildInputs = with super.python3Packages; [
      ply pygments prompt-toolkit
    ];
    inherit (super.xonsh-unwrapped) pname
                          version
                          src
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
