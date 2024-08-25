{
  disko.devices = {
    disk = {
      cocoa-main = {
        type = "disk";
        device =
          "/dev/disk/by-id/nvme-SAMSUNG_MZVLW256HEHP-000L7_S35ENX0K811123";
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
              end = "-32G";
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
      cocoa-storage = {
        type = "disk";
        device = "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_2TB_S2RMNX0J500055W";
        content = {
          type = "gpt";
          partitions = {
            STORAGE = {
              size = "100%";
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
          };
        };
      };
    };
    nodev."/" = { fsType = "tmpfs"; mountOptions = [ "size=1G" "mode=755" ]; };
    # unmanaged: M.2 SATA SSD that's currently unused
  };
}
