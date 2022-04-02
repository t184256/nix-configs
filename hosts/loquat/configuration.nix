{ pkgs, ... }:

{
  networking.hostName = "loquat";

  imports = [
    ./hardware-configuration.nix
    ../../nixos/services/dns.nix
  ];

  boot.loader.grub = { enable = true; version = 2; device = "/dev/sda"; };

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

  systemd.services.nix-daemon.serviceConfig = {
    MemoryHigh = "12G"; MemoryMax = "13G"; MemorySwapMax = "13G";
  };

  home-manager.users.monk.language-support = [ "nix" "bash" ];

  system.stateVersion = "22.05";
  home-manager.users.monk.home.stateVersion = "22.05";
}
