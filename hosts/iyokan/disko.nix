_:

{
  disko.devices = {
    disk.iyokan = {
      device = "/dev/sda";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            name = "BOOT";
            size = "500M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          root = {
            name = "ROOT";
            end = "-10G";
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
            size = "10G";
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
        mountOptions = [ "size=256M" "mode=755" ];
      };
    };
  };
}
