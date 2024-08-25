{ lib, pkgs, config, inputs, ... }:

with lib;

let
  cfg = config.system.role.deployer;
in {
  options = {
    system.role.deployer.enable = mkOption {
      default = false;
      example = true;
      description = ''
        Configure the host to edit and deploy this repo.
      '';
      type = types.bool;
    };
  };

  config = mkIf cfg.enable {
    home-manager.users.monk = {
      home.packages = [ inputs.deploy-rs.defaultPackage.${pkgs.system} ];
      language-support = [ "nix" ];
    };
    environment.persistence."/mnt/persist".users.monk.directories = [
      ".nix-configs"
    ];
  };
}
