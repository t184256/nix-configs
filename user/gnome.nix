{ pkgs, config, ... }:

{
  imports = [ ./config/no-graphics.nix ];

  home.packages = if config.system.noGraphics then [] else [
    pkgs.moka-icon-theme
  ];

  dconf.settings = if config.system.noGraphics then {} else {
    "org/gnome/shell" = {
      favorite-apps = [
        "thunderbird.desktop"
        "firefox.desktop"
        "console.desktop"
        "org.gnome.Nautilus.desktop"
      ];
      disable-user-extensions = false;
      enabled-extensions = [
        "autohide-battery@sitnik.ru"
        "autohide-volume@unboiled.info"
        "gsconnect@andyholmes.github.io"
        "just-perfection-desktop@just-perfection"
        "syncthing@gnome.2nv2u.com"
        "unite@hardpixel.eu"
      ];
    };
    "org/gnome/shell/keybindings" = {
        toggle-overview = [ "<Super><Alt>y" ];
        toggle-application-view = [ "<Super><Alt>x" ];
        switch-to-application-1 = [ "<Super><Alt>a" ];
        switch-to-application-2 = [ "<Super><Alt>r" ];
        switch-to-application-3 = [ "<Super><Alt>s" ];
        switch-to-application-4 = [ "<Super><Alt>t" ];
        switch-to-application-5 = [ "<Super><Alt>d" ];
    };
    "org/gnome/desktop/wm/keybindings" = {
      switch-to-workspace-1 = [ "<Super><Alt>q" ];
      switch-to-workspace-2 = [ "<Super><Alt>w" ];
      switch-to-workspace-3 = [ "<Super><Alt>f" ];
      switch-to-workspace-4 = [ "<Super><Alt>p" ];
      switch-to-workspace-5 = [ "<Super><Alt>g" ];
    };
    "org/gnome/desktop/wm/preferences" = {
      mouse-button-modifier = "<Control>";  # will break apps, but let's try
      num-workspaces = 5;
      titlebar-font = "Iosevka Term 14";
    };
    "org/gnome/mutter".dynamic-workspaces = false;
    "org/gnome/desktop/interface" = {
      gtk-theme = "Adwaita-dark";
      icon-theme = "Moka";
      clock-show-date = false;
      font-name = "Noto Sans ExtraCondensed 14";
      document-font-name = "Noto Sans ExtraCondensed 14";
      monospace-font-name = "Iosevka Term 14";
    };
    "org/gnome/shell/extensions/unite" = {
      desktop-name-text = "";
      show-window-buttons = "never";
      reduce-panel-spacing = true;
      notifications-position = "right";
    };
    "org/gnome/shell/extensions/just-perfection" = {
      clock-menu-position = 1;  # right
      clock-menu-position-offset = 9;  # rightmost, actually
      animation = 3;  # Faster
      activities-button = false;
      app-menu-icon = false;
      search = false;
      workspace = false;
      workspace-popup = false;
    };
    "org/gnome/desktop/background" = {
      primary-color = "#000000";
      picture-options = "none";
    };
    "org/gnome/GWeather".temperature-unit = "centigrade";
    "org/gnome/nautilus/preferences" = {
      default-folder-viewer = "list-view";
    };
  };
}
