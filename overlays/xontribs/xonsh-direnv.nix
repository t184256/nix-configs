{ pkgs, python3Packages }:

python3Packages.buildPythonPackage {
  pname = "xontrib-xonsh-direnv";
  version = "1.6.1";
  src = pkgs.fetchFromGitHub {
    owner = "74th";
    repo = "xonsh-direnv";
    rev = "3bea5847b9459c5799c64966ec85e624d0be69b9";
    sha256 = "sha256-h56Gx/MMCW4L6nGwLAhBkiR7bX+qfFk80LEsJMiDtjQ=";
  };
  propagatedBuildInputs = [ pkgs.direnv ];
  meta = {
    homepage = "https://github.com/74th/xonsh-direnv";
    license = pkgs.lib.licenses.mit;
    description = "xonsh direnv";
  };
}
