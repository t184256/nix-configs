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
    })
  ];
}
