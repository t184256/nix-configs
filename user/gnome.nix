{ config, ... }:

{
  imports = [ ./config/no-graphics.nix ];

  dconf.settings = if config.system.noGraphics then {} else {
    "org/gnome/shell" = {
      favorite-apps = [
        "org.gnome.Geary.desktop"
        "firefox.desktop"
        "term-hopper.desktop"
        "org.gnome.Nautilus.desktop"
      ];
      keybindings = [
        switch-to-application-1 = [ "<Super><Alt>1" ];
        switch-to-application-2 = [ "<Super><Alt>2" ];
        switch-to-application-3 = [ "<Super><Alt>3" ];
      ];
    };
  };
}
