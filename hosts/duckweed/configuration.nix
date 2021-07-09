{ pkgs, ... }:

{
  networking.hostName = "duckweed";

  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/A2EB-3AB7";
    fsType = "vfat";
    options = [ "nofail" ];
  };
  boot.kernelParams = [ "console=ttyS0" ];

  nix.autoOptimiseStore = true;  # it's tight on disk space

  users.users.monk = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  system.noGraphics = true;
  home-manager.users.monk.system.noGraphics = true;

  system.stateVersion = "21.05";
  home-manager.users.monk.home.stateVersion = "21.05";
}
