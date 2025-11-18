{ pkgs, ... }:

{
  networking.hostName = "quince";

  imports = [
    ../../nixos/profiles/2024.nix
    ./disko.nix
    ./hardware.nix
    ./network.nix
    ./secureboot.nix
    ../../nixos/services/garage.nix
    #../../nixos/services/ipfs/cluster-leader.nix
    #../../nixos/services/ipfs/node.nix
    ../../nixos/services/microsocks.nix
    ../../nixos/services/nebula ../../nixos/services/nebula/2024.nix
    ../../nixos/services/syncthing.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.cpu.intel.updateMicrocode = true;
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

  nixpkgs.flake.setNixPath = false;  # save disk space
  nixpkgs.flake.setFlakeRegistry = false;  # save disk space

  system.noGraphics = true;
  home-manager.users.monk.system.noGraphics = true;

  home-manager.users.monk.home.stateVersion = "24.05";
  system.stateVersion = "24.05";

  #services.kubo.settings.Datastore.StorageMax = "20G";

  system.role.physical.enable = true;
  system.role.virtualizer.enable = true;
}
