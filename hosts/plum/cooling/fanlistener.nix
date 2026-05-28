{ pkgs, ... }:

{
  networking.firewall.interfaces."unboiled".allowedUDPPorts = [ 9271 9272 ];

  systemd.services.fanlistener-usb = {
    description = "Fan noise measurement daemon (USB mic)";
    wantedBy = [ "multi-user.target" ];
    after = [ "alsa-restore.service" ];
    serviceConfig = {
      ExecStart =
        "${pkgs.python3.withPackages (ps: [ ps.sounddevice ps.numpy ])}"
        + "/bin/python3 ${./fanlistener.py} 'USB Microphone'";
      Restart = "on-failure";
    };
  };

  systemd.services.fanlistener-analog = {
    description = "Fan noise measurement daemon (analog mic)";
    wantedBy = [ "multi-user.target" ];
    after = [ "alsa-restore.service" ];
    serviceConfig = {
      Environment = [ "PORT=9272" ];
      ExecStart =
        "${pkgs.python3.withPackages (ps: [ ps.sounddevice ps.numpy ])}"
        + "/bin/python3 ${./fanlistener.py} 'HD-Audio Generic: ALC897 Analog'";
      Restart = "on-failure";
    };
  };
}
