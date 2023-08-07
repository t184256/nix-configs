{ config, lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci" "thunderbolt" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];
  boot.supportedFilesystems = [ "bcachefs" ];
  boot.initrd.supportedFilesystems = [ "bcachefs" "vfat" ];

  # Impermanence + other bcachefs subvolumes
  fileSystems = {
    "/boot" = { label = "COCOA_BOOT"; fsType = "vfat"; };
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [ "defaults" "size=2G" "mode=755" ];
      neededForBoot = true;
    };
    "/mnt/persist" = {
      device = "/dev/disk/by-partlabel/COCOA";
      fsType = "bcachefs";
      neededForBoot = true;
    };
    "/nix" = {
      device = "/mnt/persist/nix";
      options = [ "bind" ];
      neededForBoot = true;
    };
    #"/mnt/sync" = {
    #  label = "COCOA";
    #  fsType = "bcachefs";
    #  options = [ "subvol=sync" ];
    #};
    "/home" = { device = "/mnt/persist/home"; options = [ "bind" ]; };
  };

  swapDevices = [ { device = "/dev/mapper/COCOA_SWAP"; } ];
  boot.initrd.luks.devices.COCOA_SWAP = {
    device = "/dev/disk/by-partlabel/COCOA_SWAP";
  };

  # CPU
  powerManagement.cpuFreqGovernor = "ondemand";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
