{ pkgs, ... }:

{
  networking.firewall.interfaces."unboiled".allowedUDPPorts = [ 9271 ];

  systemd.services.calibrate-fanlistener = {
    description = "Fan noise measurement daemon";
    wantedBy = [ "multi-user.target" ];
    after = [ "alsa-restore.service" ];
    serviceConfig = {
      ExecStartPre = pkgs.writeShellScript "wait-for-audio-hw3" ''
        until [ -e /dev/snd/pcmC3D0c ]; do sleep 1; done
      '';
      ExecStart =
        "${pkgs.python3.withPackages (ps: [ ps.sounddevice ps.numpy ])}"
        + "/bin/python3 ${./calibrate-fanlistener.py} hw:3,0";
      Restart = "on-failure";
    };
  };
}
