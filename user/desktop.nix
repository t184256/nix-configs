{ pkgs, config, lib, ... }:

{
  imports = [ ./config/no-graphics.nix ./config/live.nix ];

  # Random assortment of GUI tools
  home.packages = lib.mkIf (! config.system.noGraphics && ! config.system.live)
    (with pkgs; [
      meld
      dino
      transmission-remote-gtk
      moonlight-qt
      gnome-session  # for gnome-session-inhibit
    ]);
}
