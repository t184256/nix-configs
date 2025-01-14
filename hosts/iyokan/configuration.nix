{ pkgs, ... }:

{
  networking.hostName = "iyokan";

  imports = [
    ./disko.nix
    ./hardware.nix
    ../../nixos/profiles/2024.nix
    #../../nixos/services/microsocks.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  nixpkgs.flake.setNixPath = false;  # save disk space
  nixpkgs.flake.setFlakeRegistry = false;  # save disk space

  system.noGraphics = true;
  home-manager.users.monk.system.noGraphics = true;

  home-manager.users.monk.home.stateVersion = "24.11";
  system.stateVersion = "24.11";
}
