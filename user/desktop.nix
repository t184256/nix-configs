{ pkgs, config, lib, ... }:

{
  imports = [ ./config/no-graphics.nix ];

  # Random assortment of GUI tools
  home.packages = lib.mkIf (! config.system.noGraphics) (with pkgs; [
    dino
    transmission-remote-gtk
    giara
    kodi-wayland
    moonlight-qt
  ]);
}
