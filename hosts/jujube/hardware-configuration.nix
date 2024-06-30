{ config, lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Impermanence + other btrfs subvolumes
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [ "defaults" "size=2G" "mode=755" ];
    neededForBoot = true;
  };
  fileSystems."/mnt/persist" = {
    device = "/dev/disk/by-label/JUJUBE";
    fsType = "btrfs";
    options = [ "subvolid=0" ];
    neededForBoot = true;
  };
  fileSystems."/nix" = {
    device = "/dev/disk/by-label/JUJUBE";
    fsType = "btrfs";
    options = [ "subvol=nix" ];
    neededForBoot = true;
  };
  fileSystems."/home" = {
    device = "/dev/disk/by-label/JUJUBE";
    fsType = "btrfs";
    options = [ "subvol=home" ];
  };

  boot.initrd.luks.devices."JUJUBE".device = "/dev/disk/by-partlabel/JUJUBE";

  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-label/JUJUBE_BOOT";
    fsType = "vfat";
  };

  swapDevices = [ { device = "/dev/disk/by-label/JUJUBE_SWAP"; } ];
  boot.initrd.luks.devices."JUJUBE_SWAP".device =
    "/dev/disk/by-partlabel/JUJUBE_SWAP";

  # CPU
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
