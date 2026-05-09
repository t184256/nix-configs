{ pkgs, ... }:

{
  networking.firewall.interfaces."unboiled".allowedTCPPorts = [ 9272 ];

  systemd.services.calibrate-fancontroller = {
    description = "Fan control daemon for calibration";
    conflicts   = [ "gpu-fancontrol.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3.withPackages (ps: [ ])}/bin/python3 ${./fanctl_daemon.py}";
      Restart   = "no";
    };
  };
}
