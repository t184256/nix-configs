{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  boot.initrd.kernelModules = [ "nvme" ];

  fileSystems = {
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [ "defaults" "size=256M" "mode=755" ];
      neededForBoot = true;
    };
    "/nix" = {
      device = "/dev/disk/by-partlabel/ARACEAE";
      options = [ "subvol=/nix" ];
      fsType = "btrfs";
      neededForBoot = true;
    };
    "/mnt/persist" = {
      device = "/dev/disk/by-partlabel/ARACEAE";
      options = [ "compress=zstd:15" ];
      fsType = "btrfs";
      neededForBoot = true;
    };
    "/boot" = {
      device = "/dev/disk/by-partlabel/ARACEAE_BOOT";
      fsType = "vfat";
    };
  };

  swapDevices = [ { device = "/dev/disk/by-partlabel/ARACEAE_SWAP"; } ];
}
