{ pkgs, config, lib, ... }:

{
  imports = [ ./config/no-graphics.nix ];

  home.packages = lib.mkIf (! config.system.noGraphics) (with pkgs; [
    libreoffice
    inkscape
    xournalpp
  ]);
}
