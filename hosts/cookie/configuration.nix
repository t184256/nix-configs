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

  time.timeZone = "Europe/Prague";

  environment.systemPackages = with pkgs; [
    firefox-wayland alacritty
    gparted parted cryptsetup btrfs-progs bcachefs-tools
    microdnf
    evtest
  ];

  services.xserver.displayManager.autoLogin = { enable = true; user = "monk"; };
  system.role = {
    desktop.enable = true;
    physical.enable = true;
    physical.portable = true;
    yubikey.enable = true;
  };
#
#  home-manager.users.monk.language-support = [ "nix" "bash" ];

  system.stateVersion = "22.05";
  home-manager.users.monk.home.stateVersion = "22.05";
}
