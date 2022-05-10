{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./laptop-X2x0-jap-keyboard-remap.nix
    ./laptop-X2x0-nitrocaster-mod.nix
    ./laptop-X2x0.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "cola"; # Define your hostname.
  networking.networkmanager.enable = true;
  time.timeZone = "Europe/Prague";

  sound.enable = true;
  hardware.pulseaudio.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.monk = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  environment.systemPackages = with pkgs; [
    firefox-wayland
  ];

  services.openssh.enable = true;

  system.role = {
    desktop.enable = true;
    physical.enable = true;
    physical.portable = true;
    yubikey.enable = true;
  };

  system.stateVersion = "21.05";
  home-manager.users.monk.home.stateVersion = "21.05";

  home-manager.users.monk.language-support = [
    "nix" "bash" "haskell"
  ];

  programs.adb.enable = true;
  users.extraGroups.plugdev.members = [ "monk" ];
  networking.firewall.allowedTCPPorts = [ 3389 ];  # RDP
}

