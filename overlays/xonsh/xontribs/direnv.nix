{ pkgs }:

pkgs.python3Packages.buildPythonPackage {
  pname = "xonsh-direnv";
  version = "1.5";
  src = pkgs.fetchFromGitHub {
    owner = "74th";
    repo = "xonsh-direnv";
    rev = "85c9a378599ab560cf2d41b8a5c1f15a233aa228";
    sha256 = "1hr43g5blyqpc9xvd3v27s48bqc8mnc0vxficqfcghbqmi5jhfvb";
  };
  propagatedBuildInputs = [ pkgs.direnv ];
  meta = {
    homepage = "https://github.com/74th/xonsh-direnv";
    license = pkgs.lib.licenses.mit;
    description = "xonsh direnv";
  };
}
