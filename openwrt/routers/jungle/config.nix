_:

{
  imports = [
    ./tx-hack.nix
    ./on-device-secrets.nix
  ];

  uci.packageManager = "apk";
  uci.sshKeys = [ (builtins.readFile ../../../misc/pubkeys/ssh) ];
}
