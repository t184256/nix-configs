_: super:

{
  fedifetcher-restored = super.python3.pkgs.buildPythonApplication rec {
    pname = "fedifetcher";
    version = "7.1.17";
    format = "other";

    src = super.fetchFromGitHub {
      owner = "nanos";
      repo = "FediFetcher";
      tag = "v${version}";
      hash = "sha256-jFUT+s2tQ3gTYLbrEgKGrBI+Pi9n12drPCWIHmFZx14=";
    };

    propagatedBuildInputs = with super.python3.pkgs; [
      defusedxml
      python-dateutil
      requests
      xxhash
    ];

    installPhase = ''
      runHook preInstall
      install -vD find_posts.py $out/bin/fedifetcher
      runHook postInstall
    '';

    checkPhase = ''
      runHook preCheck
      $out/bin/fedifetcher --help>/dev/null
      runHook postCheck
    '';

    meta.mainProgram = "fedifetcher";
  };
}
