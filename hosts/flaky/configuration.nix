{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.grub = { enable = true; version = 2; device = "/dev/sda"; };

  networking.hostName = "flaky"; # Define your hostname.
  networking.interfaces.ens3.useDHCP = true;

  time.timeZone = "Europe/Prague";

  environment.systemPackages = with pkgs; [
    git wget vim
  ];

  services.openssh.enable = true;

  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  users.users.monk = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  system.stateVersion = "20.09";
  home-manager.users.monk.home.stateVersion = "20.09";

  system.noGraphics = true;
  home-manager.users.monk.system.noGraphics = true;

  home-manager.users.monk.language-support = [ "nix" "python" "bash" ];

  system.buildserver-aarch64.enable = true;
}
