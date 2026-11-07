{ lib, config, modulesPath, ... }:
# for hardware inventory and links, see hosts/plum/README.md

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot = {
    initrd.availableKernelModules = [
      "ahci"
      "nvme"
      "sd_mod"
      "usb_storage"
      "usbhid"
      "xhci_pci"
    ];
    initrd.kernelModules = [ "thunderbolt" ];  # gives thunderbolt time to init
    kernelModules = [ "kvm-amd" "asus-ec-sensors" "nct6775" ];
    blacklistedKernelModules = [ "spd5118" ];  # temp-only, nct6775 has PWM
    kernelParams = [ "iommu=pt" "pcie_aspm=off" ];
  };

  # dedicated subvolume for the btrfs swapfile (see configuration.nix)
  fileSystems."/var/swap" = {
    device = "/dev/mapper/root";
    fsType = "btrfs";
    options = [ "noatime" "subvol=/swap" ];
  };

  fileSystems."/mnt/persist".neededForBoot = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
