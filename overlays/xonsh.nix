self: super:
let
  pyExtra = with super.python3Packages; [ nixpkgs ];
  xontribs = [];
in
{
  xonsh = super.xonsh.overridePythonAttrs (old: rec {
    version = "0.9.24";
    src = super.fetchFromGitHub {
      owner  = "xonsh";
      repo   = "xonsh";
      rev    = version;
      sha256 = "1nk7kbiv7jzmr6narsnr0nyzkhlc7xw3b2bksyq2j6nda67b9b3y";
    };
    propagatedBuildInputs = old.propagatedBuildInputs ++ pyExtra ++ xontribs;
  });
}
