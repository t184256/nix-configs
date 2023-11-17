{ config, lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "aesni_intel"
    "ahci"
    "nvme"
    "sd_mod"
    "sdhci_pci"
    "usb_storage"
    "usbhid"
    "xhci_pci"
  ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];
  boot.supportedFilesystems = [ "xfs" ];
  boot.initrd.supportedFilesystems = [ "xfs" "vfat" ];

  fileSystems = {
    "/boot" = { label = "QUINCE_BOOT"; fsType = "vfat"; };
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [ "defaults" "size=2G" "mode=755" ];
      neededForBoot = true;
    };
    "/mnt/persist" = {
      device = "/dev/mapper/QUINCE";
      fsType = "xfs";
      neededForBoot = true;
    };
    "/nix" = {
      device = "/mnt/persist/nix";
      options = [ "bind" ];
      neededForBoot = true;
    };
    "/home" = { device = "/mnt/persist/home"; options = [ "bind" ]; };
  };

  boot.initrd.luks.devices.QUINCE.device = "/dev/disk/by-partlabel/QUINCE";

  swapDevices = [ ];

  # CPU
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
