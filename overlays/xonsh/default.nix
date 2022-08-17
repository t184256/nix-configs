self: super:

let
  xontribs = builtins.mapAttrs (_: f: (f { pkgs = super; }))
                               ((import ../../.autoimport).asAttrs ./xontribs);

  # avoids https://github.com/xonsh/xonsh/issues/3810
  ptk = super.python3Packages.prompt_toolkit.overridePythonAttrs ({
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
    inherit (super.xonsh) postPatch
                          meta shellPath;
    pname = "xonsh";
    version = "0.13.1+";
    src = super.fetchFromGitHub {
      owner = "xonsh";
      repo = "xonsh";
      rev = "588881803c4007b20204cc56a07609ac931ebd95";
      sha256 = "sha256-03D5krSAnexU3KTQ2WKkdTT6dk77CNZ0OjtvzCzA8T4=";
    };
    propagatedBuildInputs = with super.python3Packages; [
      ply
      ptk
      pygments
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
      "test_bsd_man_page_completions"
      "test_xonsh_activator"
      # fails on non-interactive shells
      "test_capture_always"
      "test_casting"
      "test_command_pipeline_capture"
      "test_dirty_working_directory"
      "test_man_completion"
      "test_vc_get_branch"
      "test_bash_and_is_alias_is_only_functional_alias"
    ];
    disabledTestPaths = [
      # fails on sandbox
      "tests/completers/test_command_completers.py"
      "tests/test_ptk_highlight.py"
      "tests/test_ptk_shell.py"
      # fails on non-interactive shells
      "tests/prompt/test_gitstatus.py"
      "tests/completers/test_bash_completer.py"
    ];
    postInstall = ''
      site_packages=$(python -c "import site; print(site.__file__.rsplit('/', 2)[-2])")
      xonsh=$out/lib/$site_packages/site-packages/xonsh/
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
