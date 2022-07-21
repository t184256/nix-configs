{ ... }:

{
  xdg.dataFile = {
    # disable system fonts
    "applications/firefox.desktop".text = ''
      [Desktop Entry]
      Exec=no-system-fonts firefox %u
      Version=1.0
      Name=Firefox
      GenericName=Web Browser
      Comment=Browse the Web
      Icon=firefox
      Terminal=false
      Type=Application
      MimeType=text/html;text/xml;application/xhtml+xml;application/vnd.mozilla.xul+xml;text/mml;x-scheme-handler/http;x-scheme-handler/https;
      StartupNotify=true
      Categories=Network;WebBrowser;
      Keywords=web;browser;internet;
    '';
  };
  dconf.settings = {
    "org/gnome/shell" = {
      favorite-apps = [
        "org.gnome.Nautilus.desktop"
        "firefox.desktop"
        "console.desktop"
      ];
      disable-user-extensions = false;
      enabled-extensions = [
        #"allowlockedremotedesktop@kamens.us"
        "autohide-battery@sitnik.ru"
        "autohide-volume@unboiled.info"
        "focus-changer@heartmire"
        "gnome-kinit@bonzini.gnu.org"
        "just-perfection-desktop@just-perfection"
        #"noannoyance@daase.net"
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
      begin-move = [ "<Super><Alt>y" ];
      move-to-monitor-left = [ "<Super><Left>" ];
      move-to-monitor-down = [ "<Super><Down>" ];
      move-to-monitor-right = [ "<Super><Right>" ];
      move-to-monitor-up = [ "<Super><Up>" ];
    };
    "org/gnome/shell/extensions/focus-changer" = {
      focus-left = [ "<Control><Alt><Super>Left" ];
      focus-down = [ "<Control><Alt><Super>Down" ];
      focus-right = [ "<Control><Alt><Super>Right" ];
      focus-up = [ "<Control><Alt><Super>Up" ];
    };
    "org/gnome/settings-daemon/plugins/media-keys" = {
      magnifier = [ ];
      screensaver = [ "<Alt><Super>8" ];
    };
    "org/gnome/desktop/wm/preferences" = {
      mouse-button-modifier = "<Control>";  # will break apps, but let's try
      num-workspaces = 5;
      titlebar-font = "Iosevka Term 14";
    };
    "org/gnome/mutter".dynamic-workspaces = false;
    "org/gnome/desktop/interface" = {
      #gtk-theme = "Adwaita-dark";
      #icon-theme = "Moka";
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
      activities-button = true;
      app-menu-icon = false;
      search = false;
      #workspace = false;
      #workspace-popup = false;
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
