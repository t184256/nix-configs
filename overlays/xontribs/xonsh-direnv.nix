{ pkgs, python3Packages }:

python3Packages.buildPythonPackage rec {
  pname = "xontrib-xonsh-direnv";
  version = "1.6.3";
  src = pkgs.fetchFromGitHub {
    owner = "74th";
    repo = "xonsh-direnv";
    rev = version;
    sha256 = "sha256-97c2cuqG0EitDdCM40r2IFOlRMHlKC4cLemJrPcxsZo=";
  };
  propagatedBuildInputs = [ pkgs.direnv ];
  meta = {
    homepage = "https://github.com/74th/xonsh-direnv";
    license = pkgs.lib.licenses.mit;
    description = "xonsh direnv";
  };
}
