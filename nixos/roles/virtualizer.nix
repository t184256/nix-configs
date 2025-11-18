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
  };

  config = mkIf cfg.enable {
    virtualisation.libvirtd = {
      enable = true;
      allowedBridges = lib.mkForce [];
      qemu.runAsRoot = false;
      nss.enableGuest = true;
      sshProxy = true;
    };
    users.users.monk.extraGroups = [ "libvirtd" ];

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
  };
}
