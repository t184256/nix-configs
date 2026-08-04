{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.system.role.yubikey;
in {
  options = {
    system.role.yubikey.enable = mkOption {
      default = false;
      example = true;
      description = ''
        Install tools I need to use to support Yubikey hardware.
      '';
      type = types.bool;
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      services.pcscd.enable = true;
      services.udev.packages = [ pkgs.yubikey-personalization ];
      programs.ssh.startAgent = false;
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if ((action.id == "org.debian.pcsc-lite.access_pcsc" ||
               action.id == "org.debian.pcsc-lite.access_card") &&
              subject.isInGroup("users")) {
            return polkit.Result.YES;
          }
        });
      '';
    })
  ];
}
