self: super:

let
  xontribs = builtins.mapAttrs (_: f: (f { pkgs = super; }))
                               ((import ../../.autoimport).asAttrs ./xontribs);

  # avoids https://github.com/xonsh/xonsh/issues/3810
  ptk = super.python3Packages.prompt_toolkit.overridePythonAttrs (_: rec {
    version = "3.0.20+";
    src = super.fetchFromGitHub {
      owner = "t184256";
      repo = "python-prompt-toolkit";
      rev = "03f43de881c96419748a1dd1e690fed9f826fe64";
      sha256 = "0hiym1ydyp6mk97qxibqb0qkyp5rilyzn1a82abp64aihyyl11hp";
    };
  });

  xonshLib = super.python3Packages.buildPythonPackage rec {
    inherit (super.xonsh) postPatch
                          meta shellPath;
    pname = "xonsh";
    version = "0.10.1+";
    src = super.fetchFromGitHub {
      owner = "xonsh";
      repo = "xonsh";
      rev = "e762dc57ab9e195f90a4600d4fe547df0bc09b46";
      sha256 = "1617dq4h7rfkh44mhiy418jk22j3cbq9lp44zl6fjcivn99bpp03";
    };
    propagatedBuildInputs = with super.python3Packages; [
      ply
      pygments
      ptk
      pyte
    ];
    prePatch = ''
      substituteInPlace xonsh/completers/bash_completion.py --replace \
        '{source}' \
        'PS1=x [ -r /etc/bashrc ] && source /etc/bashrc; {source}'
    '';
    preCheck = ''
      HOME=$TMPDIR
    '';
    checkInputs = with super; [ glibcLocales git ] ++ (with python3Packages; [
      pytestCheckHook pytest-subprocess pytest-rerunfailures pytest-mock
    ]);
    disabledTests = [
      # fails on sandbox
      "test_colorize_file"
      "test_loading_correctly"
      "test_no_command_path_completion"
      # fails on non-interactive shells
      "test_capture_always"
      "test_casting"
      "test_command_pipeline_capture"
      "test_dirty_working_directory"
      "test_man_completion"
      "test_vc_get_branch"
    ];
    disabledTestPaths = [
      # fails on non-interactive shells
      "tests/prompt/test_gitstatus.py"
      "tests/completers/test_bash_completer.py"
    ];
    postInstall = ''
      site_packages=$(python -c "import site; print(site.__file__.rsplit('/', 2)[-2])")
      xonsh=$out/lib/$site_packages/site-packages/xonsh/
      install -D -m644 xonsh/parser_table.py xonsh/__amalgam__.py $xonsh
      install -D -m644 xonsh/completers/__amalgam__.py $xonsh/completers/
      install -D -m644 xonsh/history/__amalgam__.py $xonsh/history/
      install -D -m644 xonsh/prompt/__amalgam__.py $xonsh/prompt/
      python -m compileall --invalidation-mode unchecked-hash $xonsh
    '';
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
