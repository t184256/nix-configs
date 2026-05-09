{ pkgs, ... }:

{
  networking.firewall.interfaces."unboiled".allowedTCPPorts = [ 9272 ];

  systemd.services.calibrate-fancontroller = {
    description = "Fan control daemon for calibration";
    conflicts   = [ "fancontrol.service" ];
    serviceConfig = {
      ExecStart =
        "${pkgs.python3.withPackages (ps: [ ps.nvidia-ml-py ])}"
        + "/bin/python3 ${./calibrate-fancontroller.py}";
      Restart   = "no";
    };
  };
}
