{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ ];

  boot = {
    initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "sr_mod" "xen_blkfront" ];
    initrd.kernelModules = [ "dm-snapshot" ];
    kernelModules = [ ];
    extraModulePackages = [ ];
  };

  fileSystems."/mnt/persist".neededForBoot = true;
  fileSystems."/mnt/secrets".neededForBoot = true;

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
