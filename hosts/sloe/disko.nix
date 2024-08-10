_:

{
  disko.devices = {
    disk.sloe = {
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
            size = "1G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/boot";
            };
          };
          root = {
            name = "ROOT";
            end = "-32G";
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
          swap = {
            name = "SWAP";
            size = "32G";
            content = {
              type = "swap";
              resumeDevice = false;
            };
          };
        };
      };
    };
    nodev = {
      "/" = {
        fsType = "tmpfs";
        mountOptions = [ "size=512M" "mode=755" ];
      };
    };
  };
}
