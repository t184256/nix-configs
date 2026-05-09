{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "loudness" ''
      exec ${pkgs.python3.withPackages (ps: [ ps.sounddevice ps.numpy ])}/bin/python3 \
        ${./loudness.py} "$@"
    '')
  ];
}
