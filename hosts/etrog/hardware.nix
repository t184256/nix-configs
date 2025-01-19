{ lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot = {
    initrd.availableKernelModules = [
      "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod"
    ];
    kernelParams = [ "console=ttyS0" ];
    initrd.kernelModules = [ ];
    kernelModules = [ "kvm-amd" ];
    extraModulePackages = [ ];
  };

  fileSystems."/mnt/persist".neededForBoot = true;

  #swapDevices = [ "/dev/disk/by-label/SWAP" ];
  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
