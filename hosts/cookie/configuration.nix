{ pkgs, ... }:

{
  imports = [
    ./keyboard-remap.nix
  ];

  system.live = true;
  home-manager.users.monk.system.live = true;
  hardware.enableRedistributableFirmware = true;
  boot.supportedFilesystems = [ "bcachefs" "xfs" ];

  networking.hostName = "cookie";
  networking.wireless.enable = false;
  networking.networkmanager.enable = true;

  environment.systemPackages = with pkgs; [
    firefox-wayland alacritty
    gparted parted cryptsetup btrfs-progs bcachefs-tools
    dnf5
    evtest
  ];

  services.displayManager.autoLogin = { enable = true; user = "monk"; };
  system.role = {
    desktop.enable = true;
    physical.enable = true;
    physical.portable = true;
    yubikey.enable = true;
  };
#
#  home-manager.users.monk.language-support = [ "nix" "bash" ];

  #boot.kernelPackages = pkgs.linuxPackages_testing;  # needed for bcachefs now

  system.stateVersion = "24.05";
  home-manager.users.monk.home.stateVersion = "24.05";
}
