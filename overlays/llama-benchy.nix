_: prev:

{
  llama-benchy = prev.python3.pkgs.buildPythonApplication {
    pname = "llama-benchy";
    version = "0.4.0";
    src = prev.fetchFromGitHub {
      owner = "eugr";
      repo = "llama-benchy";
      rev = "446dd42fde2ebbaa1d68a0dfe9dc1e5b833f95ad";
      hash = "sha256-M+ijzaJz5XVsFSFvLGHJUic/B4PDcG0mKaTCQ/1ZHJY=";
      leaveDotGit = true;
    };
    postUnpack = "git -C $sourceRoot tag v0.4.0";  # hatch-vcs needs a tag
    pyproject = true;
    nativeBuildInputs = [
      prev.python3.pkgs.hatchling prev.python3.pkgs.hatch-vcs prev.git
    ];
    dependencies = with prev.python3.pkgs; [
      openai tokenizers transformers tabulate numpy requests aiohttp pydantic
    ];
    pythonRuntimeDepsCheckHook = "";  # skip because of 'asyncio'
    doCheck = false;
  };
}
