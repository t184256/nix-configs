{ pkgs, ... }:

{
  networking.hostName = "spondias";

  imports = [
    ../../nixos/profiles/2024.nix
    ./disko.nix
    ./hardware.nix
    ./network.nix
    ./secureboot.nix
    ../../nixos/services/nebula ../../nixos/services/nebula/2024.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.cpu.intel.updateMicrocode = true;
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

  system.noGraphics = true;
  home-manager.users.monk.system.noGraphics = true;

  home-manager.users.monk.home.stateVersion = "25.05";
  system.stateVersion = "25.05";

  system.role.physical.enable = true;
}
