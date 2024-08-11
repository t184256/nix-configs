{
  disko.devices = {
    disk = {
      quince-main = {
        type = "disk";
        device = "/dev/disk/by-id/mmc-A3A444_0x1e7ca520";
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
            luks = {
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
    # unmanaged: NVMe SSD unlocked externally
  };
}
