{ pkgs, lib, ... }:

{
  programs.command-not-found.enable = false;
  programs.nano.enable = false;
  environment.variables.EDITOR = "vi";
  documentation.info.enable = false;
  documentation.nixos.enable = false;
  environment.defaultPackages = [];
  networking.networkmanager.plugins = lib.mkForce (with pkgs; [
    # openconnect specifically pulls in graphics and sound. ugh.
    networkmanager-iodine
    networkmanager-openvpn
  ]);
}
