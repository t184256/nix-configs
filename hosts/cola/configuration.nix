{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./laptop-X2x0.nix
    ./laptop-X2x0-jap-keyboard-remap.nix
    ./nitrocaster
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
    inputs.deploy-rs.defaultPackage.${pkgs.system} hydra-cli
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

  #zramSwap = { enable = true; memoryPercent = 50; };

  systemd.services.nix-daemon.environment.TMPDIR = "/nix/tmp";  # large builds
  system.activationScripts.nixtmpdir.text = "mkdir -p /nix/tmp";

  programs.adb.enable = true;
  users.extraGroups.plugdev.members = [ "monk" ];
  networking.firewall.allowedTCPPorts = [ 3389 ];  # RDP
}

