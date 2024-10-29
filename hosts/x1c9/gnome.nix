{ ... }:

let
  # disable system fonts
  firefox_desktop = ''
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
    Actions=new-window;new-private-window;profile-manager-window;

    [Desktop Action new-window]
    Name=Open a New Window
    Exec=no-system-fonts firefox --new-window %u

    [Desktop Action new-private-window]
    Name=Open a New Private Window
    Exec=no-system-fonts firefox --private-window %u

    [Desktop Action profile-manager-window]
    Name=Open the Profile Manager
    Exec=no-system-fonts firefox --ProfileManager
  '';
in
{
  xdg.dataFile = {
    "applications/firefox.desktop".text = firefox_desktop;
    "applications/org.mozilla.firefox.desktop".text = firefox_desktop;
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
        "paperwm@paperwm.github.com"
        #"noannoyance@daase.net"
        "unite@hardpixel.eu"
      ];
    };
    # https://github.com/paperwm/PaperWM/issues/261
    "org/gnome/mutter".experimental-features = [ "scale-monitor-framebuffer" ];
    "org/gnome/shell/keybindings" = {
        toggle-overview = [ "<Shift><Alt>y" ];
        toggle-application-view = [ "<Shift><Alt>x" ];
        switch-to-application-1 = [ "<Shift><Alt>a" ];
        switch-to-application-2 = [ "<Shift><Alt>r" ];
        switch-to-application-3 = [ "<Shift><Alt>s" ];
        switch-to-application-4 = [ "<Shift><Alt>t" ];
        switch-to-application-5 = [ "<Shift><Alt>d" ];
    };
    "org/gnome/desktop/wm/keybindings" = {
      switch-to-workspace-1 = [ "<Shift><Alt>q" ];
      switch-to-workspace-2 = [ "<Shift><Alt>w" ];
      switch-to-workspace-3 = [ "<Shift><Alt>f" ];
      switch-to-workspace-4 = [ "<Shift><Alt>p" ];
      switch-to-workspace-5 = [ "<Shift><Alt>g" ];
      begin-move = [ "<Shift><Alt>y" ];
      move-to-monitor-left = [ "<Shift><Left>" ];
      move-to-monitor-down = [ "<Shift><Down>" ];
      move-to-monitor-right = [ "<Shift><Right>" ];
      move-to-monitor-up = [ "<Shift><Up>" ];
    };
    "org/gnome/shell/extensions/focus-changer" = {
      focus-left = [ "<Control><Alt><Shift>Left" ];
      focus-down = [ "<Control><Alt><Shift>Down" ];
      focus-right = [ "<Control><Alt><Shift>Right" ];
      focus-up = [ "<Control><Alt><Shift>Up" ];
    };
    "org/gnome/settings-daemon/plugins/media-keys" = {
      magnifier = [ ];
      screensaver = [ "<Alt><Shift>8" ];
    };
    "org/gnome/desktop/wm/preferences" = {
      mouse-button-modifier = "<Control>";  # will break apps, but let's try
      num-workspaces = 5;
      titlebar-font = "Iosevka Term 14";
      auto-raise = false;
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
    "org/gnome/settings-daemon/plugins/color" = {
      night-light-enabled = true;
      night-light-temperature = 3200;
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
