# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/profiles/qemu-guest.nix")
    ];

  # virtio_pci / virtio_scsi are a must according to
  # https://www.stunkymonkey.de/blog/contabo-nixos/
  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "dm-snapshot" ];  # so is this, IDK why
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [ "defaults" "size=2G" "mode=755" ];
    neededForBoot = true;
  };
  fileSystems."/mnt/persist" = {
    device = "/dev/disk/by-partlabel/LOQUAT";
    fsType = "xfs";
    neededForBoot = true;
  };

  fileSystems."/nix" = { device = "/mnt/persist/nix"; options = [ "bind" ]; };

  fileSystems."/boot" = {
    device = "/dev/disk/by-partlabel/LOQUAT_BOOT";
    fsType = "ext4";
  };

  swapDevices = [
    { device = "/dev/disk/by-partlabel/LOQUAT_SWAP"; }
  ];

  fileSystems."/mnt/storage" = {
    device = "/mnt/persist";
    options = [ "bind" ];
  };

  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
