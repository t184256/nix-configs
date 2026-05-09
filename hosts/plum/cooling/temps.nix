{ pkgs, ... }:

let
  src = pkgs.runCommand "temps-src" { } ''
    mkdir $out
    cp ${./temps.py} $out/temps.py
    cp ${./common.py} $out/common.py
    cp ${./acoustic_profile.py} $out/acoustic_profile.py
  '';
in

{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "temps" ''
      py=${pkgs.python3.withPackages (ps: [
        ps.nvidia-ml-py ps.pysensors ps.psutil
      ])}
      exec $py/bin/python3 ${src}/temps.py "$@"
    '')
  ];
}
