{ pkgs, config, lib, ... }:

{
  imports = [ ./config/no-graphics.nix ./config/live.nix ];

  home.packages = lib.mkIf (! config.system.noGraphics && ! config.system.live)
    (with pkgs; [
      libreoffice
      inkscape
      xournalpp
    ]);
}
