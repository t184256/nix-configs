{ config, lib, pkgs, ... }:

let
  cfg = config.services.fanlistener;
  py = pkgs.python3.withPackages (ps: [ ps.sounddevice ps.numpy ]);
in

{
  options.services.fanlistener = {
    enable = lib.mkEnableOption "loudness measurement daemon";
    device = lib.mkOption {
      type = lib.types.str;
      default = "USB Microphone";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 9271;
      description = "UDP port to answer probes on.";
    };
    bindAddress = lib.mkOption {
      type = lib.types.str;
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "snd-usb-audio" ];

    systemd.services.fanlistener = {
      description = "Loudness measurement daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "alsa-restore.service" "sound.target" ];
      environment = {
        PORT = toString cfg.port;
        BIND = cfg.bindAddress;
      };
      serviceConfig = {
        ExecStart = "${py}/bin/python3 ${./fanlistener.py} "
                    + lib.escapeShellArg cfg.device;
        Restart = "always";
      };
    };
  };
}
