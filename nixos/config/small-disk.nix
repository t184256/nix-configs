{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.system.smallDisk;
in {
  options = {
    system.smallDisk.enable = mkOption {
      default = false;
      example = true;
      description = ''
        Configure the host for a small disk.
      '';
      type = types.bool;
    };
  };

  config = mkIf cfg.enable {
    nix.gc.automatic = true;
    nix.gc.options = "--delete-older-than 21d";
    boot.loader.systemd-boot.configurationLimit = 5;
    nixpkgs.flake.setNixPath = false;
    nixpkgs.flake.setFlakeRegistry = false;
    services.journald.extraConfig = ''
      SystemMaxUse=500M
      RuntimeMaxUse=12M
    '';
  };
}
