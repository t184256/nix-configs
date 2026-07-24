{
  disko.devices = {
    disk = {
      grapefruit-main = {
        type = "disk";
        device =
          "/dev/disk/by-id/nvme-AirDisk_1TB_SSD_QDC448R000185P110N";
        content = {
          type = "gpt";
          partitions = {
            BOOT = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "defaults" ];
              };
            };
            ROOT = {
              end = "384G";
              content = {
                type = "luks";
                name = "root";
                settings.allowDiscards = true;
                # no settings.keyFile = interactive password entry
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
            STORAGE = {
              end = "-32G";
              content = {
                type = "luks";
                name = "storage";
                settings.allowDiscards = true;
                # no settings.keyFile = interactive password entry
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];  # overwrite existing
                  mountpoint = "/mnt/storage";
                  subvolumes = {
                    "/secrets" = {
                      mountpoint = "/mnt/storage/secrets";
                      mountOptions = [ "noatime" ];
                    };
                    "/services" = {
                      mountpoint = "/mnt/storage/services";
                      mountOptions = [ "noatime" ];
                    };
                    "/services/syncthing" = {
                      mountpoint = "/mnt/storage/services/syncthing";
                      mountOptions = [ "noatime" ];
                    };
                    "/sync" = {
                      mountpoint = "/mnt/storage/sync";
                      mountOptions = [ "noatime" ];
                      # pre-created subvolume means datacow stays enabled
                      # which is useful for non-receiveonly usage
                    };
                  };
                };
              };
            };
            SWAP = {
              size = "100%";
              content = {
                type = "luks";
                name = "swap";
                settings.allowDiscards = true;
                # no settings.keyFile = interactive password entry
                content.type = "swap";
              };
            };
          };
        };
      };
    };
    nodev."/" = { fsType = "tmpfs"; mountOptions = [ "size=1G" "mode=755" ]; };
  };
}
