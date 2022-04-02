{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];
  boot.loader.grub = { enable = true; version = 2; device = "/dev/sda"; };

  networking.hostName = "loquat"; # Define your hostname.

  time.timeZone = "Europe/Prague";

  environment.systemPackages = with pkgs; [
  ];

  users.users.monk = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  services.openssh.enable = true;

  system.noGraphics = true;
  home-manager.users.monk.system.noGraphics = true;

  home-manager.users.monk.language-support = [ "nix" "bash" ];

  system.stateVersion = "22.05";
  home-manager.users.monk.home.stateVersion = "22.05";
}
