{ config, lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];
  boot.supportedFilesystems = [ "bcachefs" ];
  boot.initrd.supportedFilesystems = [ "bcachefs" "vfat" ];

  # Impermanence + other bcachefs subvolumes
  fileSystems = {
    "/boot" = { label = "JUJUBE_BOOT"; fsType = "vfat"; };
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [ "defaults" "size=2G" "mode=755" ];
      neededForBoot = true;
    };
    "/mnt/persist" = {
      device = "/dev/disk/by-partlabel/JUJUBE";
      fsType = "bcachefs";
      neededForBoot = true;
    };
    "/nix" = {
      device = "/mnt/persist/nix";
      options = [ "bind" ];
      neededForBoot = true;
    };
    #"/mnt/sync" = {
    #  label = "JUJUBE";
    #  fsType = "bcachefs";
    #  options = [ "subvol=sync" ];
    #};
    "/home" = { device = "/mnt/persist/home"; options = [ "bind" ]; };
  };

  #boot.initrd.luks.devices."luks-d9deff2b-d668-4657-b620-d20ab34ac176".device = "/dev/disk/by-uuid/d9deff2b-d668-4657-b620-d20ab34ac176";

  # Enable swap on luks with working hibernation
  #swapDevices = [
  #  { device = "/dev/disk/by-label/JUJUBE_SWAP"; }
  #];
  #boot.initrd.secrets = { "/mnt/persist/secrets/luks.key" = null; };
  #boot.initrd.luks.devices."luks-c78b5858-ac06-4f6d-a0e5-f01569d78995" = {
  #  device = "/dev/disk/by-uuid/c78b5858-ac06-4f6d-a0e5-f01569d78995";
  #  keyFile = "/mnt/persist/secrets/luks.key";
  #};

  # CPU
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # high-resolution display
  hardware.video.hidpi.enable = lib.mkDefault true;
}
