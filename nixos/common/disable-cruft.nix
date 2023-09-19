{ pkgs, lib, ... }:

{
  programs.command-not-found.enable = false;
  documentation.info.enable = false;
  documentation.nixos.enable = false;
  environment.defaultPackages = [];
  networking.networkmanager.plugins = lib.mkForce (with pkgs; [
    # openconnect specifically pulls in graphics and sound. ugh.
    networkmanager-iodine
    networkmanager-openvpn
  ]);
}
