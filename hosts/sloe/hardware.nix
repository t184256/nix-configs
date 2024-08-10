{ lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot = {
    # virtio_pci / virtio_scsi are a must according to
    # https://www.stunkymonkey.de/blog/contabo-nixos/
    initrd.availableKernelModules = [
      "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod"
    ];
    initrd.kernelModules = [ ];
    kernelModules = [ "dm-snapshot" ];  # so is this, IDK why
    extraModulePackages = [ ];
  };

  fileSystems."/mnt/persist".neededForBoot = true;

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
