{
  disko.devices = {
    disk = {
      spondias-main = {
        type = "disk";
        device = "/dev/disk/by-id/ata-SAMSUNG_MZ7LH128HBHQ-000L1_S4VNNF0MC43551";
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
                name = "crypted";
                settings.allowDiscards = true;
                # no settings.keyFile = interactive password entry
                additionalKeyFiles = [ "/tmp/root.luks" ];  # install-only
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
