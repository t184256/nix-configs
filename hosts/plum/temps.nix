{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "temps" ''
      exec ${pkgs.python3.withPackages (ps: [ ps.nvidia-ml-py ps.pysensors ps.psutil ])}/bin/python3 \
        ${./temps.py} "$@"
    '')
  ];
}
