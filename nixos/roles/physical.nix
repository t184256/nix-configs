{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.system.role.physical;
in {
  options = {
    system.role.physical.enable = mkOption {
      default = false;
      example = true;
      description = ''
        Install tools that make sense for a physical IBM PC descendant.
      '';
      type = types.bool;
    };
    system.role.physical.portable = mkOption {
      default = false;
      example = true;
      description = ''
        Install tools that make sense for a battery-powered luggable.
      '';
      type = types.bool;
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      environment.systemPackages = with pkgs; [ lm_sensors usbutils pciutils ];
    })
    (mkIf cfg.portable {
      powerManagement.powertop.enable = true;
      environment.systemPackages = with pkgs; [ acpi powertop ];
    })
  ];
}
