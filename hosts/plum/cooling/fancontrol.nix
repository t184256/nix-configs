{ pkgs, ... }:

let
  py = pkgs.python3.withPackages (ps: [ ps.nvidia-ml-py ]);
  src = pkgs.runCommand "fancontrol-src" { } ''
    mkdir $out
    cp ${./fancontrol.py} $out/fancontrol.py
    cp ${./acoustic_profile.py} $out/acoustic_profile.py
    cp ${./common.py} $out/common.py
  '';
in

{
  systemd.services.fancontrol = {
    description = "GPU temperature fan control";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      ExecStart = "${py}/bin/python3 ${src}/fancontrol.py";
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
