_:

{
  uci.packages = [
    "python3-light" "python3-cryptography"  # on-device-secrets, bootstrap
  ];
  uci.files = [
    # same stuff as in bootstrap
    {
      path = "/usr/mtd.layout";
      content = builtins.readFile ./mtd.layout;
    }
    {
      path = "/usr/sbin/on-device-secrets";
      executable = true;
      content = builtins.readFile ../../common/on-device-secrets;
    }
    {
      path = "/usr/local/python-modules/age.py";
      content = builtins.readFile (import ../../common/python-age.nix);
    }
  ];
}
