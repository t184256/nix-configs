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
    device = "/dev/disk/by-uuid/502f6ff3-fc3b-40f9-b101-d098a0d1cdc3";
    fsType = "btrfs";
    options = [ "subvol=@" ];
    neededForBoot = true;
  };
  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/502f6ff3-fc3b-40f9-b101-d098a0d1cdc3";
    fsType = "btrfs";
    options = [ "subvol=@nix" ];
    neededForBoot = true;
  };
  fileSystems."/mnt/sync" = {
    device = "/dev/disk/by-uuid/502f6ff3-fc3b-40f9-b101-d098a0d1cdc3";
    fsType = "btrfs";
    options = [ "subvol=@sync" ];
  };
  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/502f6ff3-fc3b-40f9-b101-d098a0d1cdc3";
    fsType = "btrfs";
    options = [ "subvol=@home" ];
  };

  boot.initrd.luks.devices."luks-d9deff2b-d668-4657-b620-d20ab34ac176".device = "/dev/disk/by-uuid/d9deff2b-d668-4657-b620-d20ab34ac176";

  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-uuid/276A-F6C4";
    fsType = "vfat";
  };

  # Enable swap on luks with working hibernation
  swapDevices = [
    { device = "/dev/disk/by-uuid/e066e794-27df-40c8-b7d0-17fd463b0985"; }
  ];
  boot.initrd.secrets = { "/mnt/persist/secrets/luks.key" = null; };
  boot.initrd.luks.devices."luks-c78b5858-ac06-4f6d-a0e5-f01569d78995".device = "/dev/disk/by-uuid/c78b5858-ac06-4f6d-a0e5-f01569d78995";
  boot.initrd.luks.devices."luks-c78b5858-ac06-4f6d-a0e5-f01569d78995".keyFile = "/mnt/persist/secrets/luks.key";

  # CPU
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # high-resolution display
  hardware.video.hidpi.enable = lib.mkDefault true;
}
