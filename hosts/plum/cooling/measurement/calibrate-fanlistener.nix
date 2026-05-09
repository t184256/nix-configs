{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "calibrate-fanlistener" ''
      py=${pkgs.python3.withPackages (ps: [ ps.sounddevice ps.numpy ])}
      exec $py/bin/python3 ${./calibrate-fanlistener.py} "$@"
    '')
  ];
}
