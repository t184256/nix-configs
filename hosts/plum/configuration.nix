{ inputs, lib, ... }:

{
  networking.hostName = "plum";

  imports = [
    ../../nixos/profiles/2024.nix
    ./disko.nix
    "${inputs.nixos-hardware}/common/cpu/amd"
    "${inputs.nixos-hardware}/common/gpu/nvidia"
    ./hardware.nix
    ./network.nix
    ../../nixos/services/nebula ../../nixos/services/nebula/2024.nix
    ../../nixos/services/ik-llama-cpp.nix
    ./bench-models.nix
    ./nvidia-settings.nix
    ./clevis-highlevel.nix
    ./fancontrol.nix
    ./temps.nix
  ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    lib.hasPrefix "nvidia" (lib.getName pkg) ||
    lib.hasPrefix "cuda" pkg.name;

  hardware.nvidia.open = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.network.enable = true;
  #boot.initrd.clevis = {
  #  enable = true;
  #  useTang = true;
  #  devices.root.secretFile = "/mnt/secrets/clevis";
  #};

  home-manager.users.monk.home.stateVersion = "25.11";
  system.stateVersion = "25.11";

  systemd.sleep.settings.Sleep.AllowSuspend = false;
  services.displayManager.gdm.autoSuspend = false;

  system.role.desktop.enable = true;
  system.role.physical.enable = true;

  system.role.virtualizer.enable = true;
  system.role.virtualizer.storageLocation = "persist";
}
