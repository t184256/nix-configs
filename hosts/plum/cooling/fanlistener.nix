{ pkgs, ... }:

{
  networking.firewall.interfaces."unboiled".allowedUDPPorts = [ 9271 ];

  systemd.services.fanlistener = {
    description = "Fan noise measurement daemon (all input devices)";
    wantedBy = [ "multi-user.target" ];
    after = [ "alsa-restore.service" ];
    serviceConfig = {
      ExecStart =
        "${pkgs.python3.withPackages (ps: [ ps.sounddevice ps.numpy ])}"
        + "/bin/python3 ${./fanlistener.py}";
      Restart = "on-failure";
    };
  };
}
