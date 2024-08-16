_:

{
  disko.devices = {
    disk.sloe = {
      device = "/dev/sda";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          grub = { name = "GRUB"; size = "4M"; type = "EF02"; };
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
            end = "256G";
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
          storage = { name = "STORAGE"; end = "-32G"; };
        };
      };
    };
    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [ "size=512M" "mode=755" ];
    };
  };
}
