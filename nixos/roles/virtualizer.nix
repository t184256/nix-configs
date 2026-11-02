{ lib, pkgs, config, inputs, ... }:

with lib;

let
  cfg = config.system.role.virtualizer;
  dropin =
    pkgs.writeTextDir "lib/systemd/system/libvirtd.service.d/10-secret.conf" "";
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
        # IDK why we're rebuilding it every time anyway. no-graphics? ibus?
        qemu.package = pkgs.qemu_kvm;
        nss.enableGuest = true;
        sshProxy = true;
      };
      users.users.monk.extraGroups = [ "libvirtd" ];
      # libvirt seals its secret key to the TPM (10-secret.conf drop-in)
      # bricking libvirtd after any TPM state change. shadow this nonsense
      boot.extraSystemdUnitPaths = [ "${dropin}" ];
      environment.etc."libvirt/secret.conf".text = "encrypt_data = 0";
      environment.systemPackages = [
        pkgs.socat
        pkgs.nmap  # for ncat
        pkgs.libxml2
        (pkgs.runCommand "libvirt-ssh-proxy" {} ''
          mkdir -p $out/bin
          ln -s ${pkgs.libvirt}/libexec/libvirt-ssh-proxy \
                $out/bin/libvirt-ssh-proxy
        '')
      ];
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
            unitConfig = {
              RequiresMountsFor = "/mnt/storage /var/lib/libvirt";
              ConditionPathIsMountPoint = "/mnt/storage";
              ConditionPathIsDirectory = "/mnt/storage/var/lib/libvirt";
            };
            wantedBy = [ "mnt-storage.target" ];
            after = [ "mnt-storage.target" ];
          };
        in
        {
          libvirtd = x;
          libvirtd-config = x;
          virt-secret-init-encryption = x;
        };
    })

    (mkIf (cfg.storageLocation == "persist") {
      environment.persistence."/mnt/persist".directories = [
        "/var/lib/libvirt"
      ];
    })
  ]);
}
