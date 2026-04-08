{ pkgs, ... }:

{
  disko.devices = {
    disk = {
      plum-main = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_1TB_S7U4NU1YB17701K_1";
        content = {
          type = "gpt";
          partitions = {
            BOOT = {
              size = "768M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "defaults" ];
              };
            };
            ROOT = {
              size = "100%";
              content = {
                type = "luks";
                name = "root";
                settings.allowDiscards = true;
                additionalKeyFiles = [ "/tmp/root.luks" ];
                postMountHook = ''
                  tmpdir=$(mktemp -d)
                  mount -o subvol=/secrets /dev/mapper/$name "$tmpdir"
                  ${pkgs.clevis}/bin/clevis encrypt tang '{"url":"http://192.168.98.1:1449"}' \
                    < /tmp/root.luks > "$tmpdir/clevis"
                  umount "$tmpdir"
                  rmdir "$tmpdir"
                '';
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];  # overwrite existing
                  subvolumes = {
                    "/nix" = {
                      mountpoint = "/nix";
                      mountOptions = [ "noatime" ];
                    };
                    "/secrets" = {
                      mountpoint = "/mnt/secrets";
                      mountOptions = [ "noatime" ];
                    };
                    "/persist" = {
                      mountpoint = "/mnt/persist";
                      mountOptions = [ "noatime" ];
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
    nodev = {
      "/" = {
        fsType = "tmpfs";
        mountOptions = [ "size=256M" "mode=755" ];
      };
    };
  };
}
