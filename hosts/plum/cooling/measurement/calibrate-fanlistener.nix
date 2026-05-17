{ pkgs, ... }:

{
  networking.firewall.interfaces."unboiled".allowedUDPPorts = [ 9271 ];

  systemd.services.calibrate-fanlistener = {
    description = "Fan noise measurement daemon";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart =
        "${pkgs.python3.withPackages (ps: [ ps.sounddevice ps.numpy ])}"
        + "/bin/python3 ${./calibrate-fanlistener.py} hw:3,0";
      Restart = "on-failure";
    };
  };
}
