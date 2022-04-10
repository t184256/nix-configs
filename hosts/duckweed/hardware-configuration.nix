{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  boot.initrd.kernelModules = [ "nvme" ];

  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [ "defaults" "size=256M" "mode=755" ];
    neededForBoot = true;
  };
  fileSystems."/mnt/persist" = {
    device = "/dev/vda1";
    fsType = "ext4";
    neededForBoot = true;
  };
  fileSystems."/nix" = { device = "/mnt/persist/nix"; options = [ "bind" ]; };
}
