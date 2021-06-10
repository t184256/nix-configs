{ pkgs, config, lib, ... }:

{
  imports = [ ./config/no-graphics.nix ];

  # Random assortment of GUI tools
  home.packages = lib.mkIf (! config.system.noGraphics) [
    pkgs.dino
    pkgs.transmission-remote-gtk
  ];
}
