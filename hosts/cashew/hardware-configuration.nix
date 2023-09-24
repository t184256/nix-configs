{ config, lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];
  boot.supportedFilesystems = [ "bcachefs" ];
  boot.initrd.supportedFilesystems = [ "bcachefs" "vfat" ];

  # Impermanence + other bcachefs subvolumes
  fileSystems = {
    "/boot" = { label = "CASHEW_BOOT"; fsType = "vfat"; };
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [ "defaults" "size=2G" "mode=755" ];
      neededForBoot = true;
    };
    "/mnt/persist" = {
      device = "/dev/disk/by-partlabel/CASHEW";
      fsType = "bcachefs";
      neededForBoot = true;
    };
    "/nix" = {
      device = "/mnt/persist/nix";
      options = [ "bind" ];
      neededForBoot = true;
    };
    "/home" = { device = "/mnt/persist/home"; options = [ "bind" ]; };
  };

  swapDevices = [ { device = "/dev/disk/by-label/CASHEW_SWAP"; } ];

  # CPU
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
