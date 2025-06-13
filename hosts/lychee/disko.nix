{
  disko.devices = {
    disk = {
      lychee = {
        type = "disk";
        device =
          "/dev/disk/by-id/nvme-One-Netbook_PCI-E_512G_SSD_LAMLCHC21265186_1";
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
                    "/storage" = {
                      mountpoint = "/mnt/storage";
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
    };
    nodev."/" = { fsType = "tmpfs"; mountOptions = [ "size=1G" "mode=755" ]; };
  };
}
