{ lib, pkgs, config, inputs, ... }:

with lib;

let
  cfg = config.system.role.virtualizer;
in {
  options = {
    system.role.virtualizer.enable = mkOption {
      default = false;
      example = true;
      description = ''
        Configure the host to run VMs in an opinionated way.
      '';
      type = types.bool;
    };

    system.role.virtualizer.storageLocation = mkOption {
      default = "storage";
      example = "persist";
      description = ''
        Where to store VM data.
        - "storage": Use /mnt/storage (current default)
        - "persist": Use /mnt/persist (for impermanence)
      '';
      type = types.enum [ "storage" "persist" ];
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      virtualisation.libvirtd = {
        enable = true;
        allowedBridges = lib.mkForce [];
        qemu.runAsRoot = false;
        nss.enableGuest = true;
        sshProxy = true;
      };
      users.users.monk.extraGroups = [ "libvirtd" ];
    }

    (mkIf (cfg.storageLocation == "storage") {
      systemd.mounts = [
        {
          what = "/mnt/storage/services/libvirt";
          where = "/var/lib/libvirt";
          type = "auto";
          options = "bind,noauto,nofail";
          unitConfig.ConditionPathIsMountPoint="/mnt/storage";
          requires = [ "mnt-storage.target" ];
          after = [ "mnt-storage.mount" ];
        }
      ];
      # extra service for "mkdir -p /mnt/storage/services/libvirt/boot"?
      systemd.services =
        let
          x = {
            unitConfig.RequiresMountsFor = "/mnt/storage /var/lib/libvirt";
            unitConfig.ConditionPathIsMountPoint="/mnt/storage";
            unitConfig.ConditionPathIsDirectory="/mnt/storage/var/lib/libvirt";
            wantedBy = [ "mnt-storage.target" ];
            after = [ "mnt-storage.target" ];
          };
        in
        {
          libvirtd = x;
          libvirtd-config = x;
        };
    })

    (mkIf (cfg.storageLocation == "persist") {
      environment.persistence."/mnt/persist".directories = [
        "/var/lib/libvirt"
      ];
    })
  ]);
}
