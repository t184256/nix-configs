{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.system.role.buildserver;
in {
  options = {
    system.role.buildserver.enable = mkOption {
      default = false;
      example = true;
      description = ''
        Enable some sensible settings for a large-storage'd build box.
      '';
      type = types.bool;
    };
    system.role.buildserver.aarch64.enable = mkOption {
      default = false;
      example = true;
      description = ''
        Enable what's required to act as a build server
        for a Nix-on-Droid aarch64 device.
        https://github.com/t184256/nix-on-droid/wiki/Simple-remote-building
      '';
      type = types.bool;
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      nix.extraOptions = ''
        trusted-users = monk
        keep-derivations = true
        keep-outputs = true
      '';
    })
    (mkIf cfg.aarch64.enable {
      boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
    })
  ];
}
