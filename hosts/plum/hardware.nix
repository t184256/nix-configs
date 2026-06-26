{ lib, config, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot = {
    initrd.availableKernelModules = [
      "ahci"
      "nvme"
      "sd_mod"
      "usb_storage"
      "usbhid"
      "xhci_pci"
    ];
    initrd.kernelModules = [ "thunderbolt" ];  # gives thunderbolt time to init
    kernelModules = [ "kvm-amd" "nct6687" ];
    extraModulePackages = with config.boot.kernelPackages; [ nct6687d ];
    extraModprobeConfig = "options nct6687 msi_fan_brute_force=1";
    kernelParams = [ "iommu=pt" "pcie_aspm=off" ];
  };

  fileSystems."/mnt/persist".neededForBoot = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
