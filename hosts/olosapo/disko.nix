_:

{
  disko.devices = {
    disk.olosapo-main = {
      device = "/dev/sda";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          grub = {
            name = "GRUB";
            size = "4M";
            type = "EF02";
          };
          boot = {
            name = "BOOT";
            size = "480M";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/boot";
            };
          };
          root = {
            name = "ROOT";
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];  # overwrite existing
              subvolumes = {
                "nix".mountpoint = "/nix";
                "secrets".mountpoint = "/mnt/secrets";
                "persist".mountpoint = "/mnt/persist";
              };
            };
          };
        };
      };
    };
    # unmanaged: /dev/sdb unlocked externally
    nodev = {
      "/" = {
        fsType = "tmpfs";
        mountOptions = [ "size=256M" "mode=755" ];
      };
    };
  };
}
