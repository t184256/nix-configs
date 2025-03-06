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
  steps = [
    0.16666667
    0.25
    0.33333334
    0.41666667
    0.5
    0.58333334
    0.66666667
    0.75
    0.83333334
    1
  ];
  mkWorkspace = i: {
    background = "";
    color = "rgb(0, 0, 0)";
    index = i - 1;
    name = builtins.toString i;
  };
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
        "autohide-battery@sitnik.ru"
        "autohide-volume@unboiled.info"
        "freon@UshakovVasilii_Github.yahoo.com"
        "gnome-kinit@bonzini.gnu.org"
        "just-perfection-desktop@just-perfection"
        "openbar@neuromorph"
        "paperwm@paperwm.github.com"
        "unite@hardpixel.eu"
        #"noannoyance@daase.net"
      ];
    };
    # https://github.com/paperwm/PaperWM/issues/261
    "org/gnome/mutter".experimental-features = [ "scale-monitor-framebuffer" ];
    "org/gnome/shell/keybindings" = {  # a remnant, not sure about these
        toggle-overview = [ "<Shift><Alt>y" ];
    };
    "org/gnome/settings-daemon/plugins/media-keys" = {
      magnifier = [ ];
      #screensaver = [ "<Alt><Shift>8" ];
    };
    "org/gnome/desktop/wm/preferences" = {
      mouse-button-modifier = "<Control>";  # will break apps, but let's try
      num-workspaces = 5;
      titlebar-font = "Iosevka Term 14";
      workspace-names = [ "1" "2" "3" "4" "5" ];
    };
    "org/gnome/mutter".dynamic-workspaces = false;
    "org/gnome/desktop/interface" = {
      #gtk-theme = "Adwaita-dark";
      #icon-theme = "Moka";
      color-scheme = "prefer-dark";
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
      restrict-to-primary-screen = false;
      hide-activities-button = "never";
      use-activities-text = false;
      #show-appmenu-icon = true;
      hide-app-menu-icon = false;
      #show-desktop-name = true;
      desktop-name-text = "";  # could be hostname, but I'm feeling minimalistic
      show-window-buttons = "never";
      reduce-panel-spacing = true;
      notifications-position = "right";
      show-legacy-tray = false;
    };
    "org/gnome/shell/extensions/just-perfection" = {
      animation = 3;  # Faster
      #activities-button = false;
      app-menu-icon = false;
      clock-menu-position = 1;  # right
      clock-menu-position-offset = 9;  # rightmost, actually
      power-icon = false;
      search = false;
      window-maximized-on-create = true;
      #workspace = false;
      workspace-popup = false;
    };
    "org/gnome/shell/extensions/paperwm" = {
      cycle-height-steps = steps;
      cycle-width-steps = steps;
      disable-topbar-styling = true;
      horizontal-margin = 0;
      show-open-position-icon = false;
      show-window-position-bar = false;
      show-workspace-indicator = false;  # show a pill instead
      vertical-margin = 0;
      vertical-margin-bottom = 0;
      window-gap = 0;
      use-default-background = false;
    };
    "org/gnome/shell/extensions/paperwm/keybindings" = {
      cycle-width = ["<Shift><Alt>t"];
      cycle-width-backwards = ["<Shift><Alt>a"];
      switch-global-left = ["<Shift><Alt>r"];
      switch-global-right = ["<Shift><Alt>s"];
      switch-down-workspace-from-all-monitors = ["<Shift><Alt>f"];
      switch-up-workspace-from-all-monitors = ["<Shift><Alt>w"];
      take-window = ["<Shift><Alt>x"];  # experimental
    };
    "org/gnome/shell/extensions/paperwm/workspaces" = {
      list = [ "1" "2" "3" "4" "5" ];
    };
    "org/gnome/shell/extensions/paperwm/workspaces/1" = mkWorkspace 1;
    "org/gnome/shell/extensions/paperwm/workspaces/2" = mkWorkspace 2;
    "org/gnome/shell/extensions/paperwm/workspaces/3" = mkWorkspace 3;
    "org/gnome/shell/extensions/paperwm/workspaces/4" = mkWorkspace 4;
    "org/gnome/shell/extensions/paperwm/workspaces/5" = mkWorkspace 5;
    "org/gnome/shell/extensions/openbar" = {
      bgcolor = [ "0" "0" "0" ];
      dark-bgcolor = [ "0" "0" "0" ];
      mscolor = [ "0.3" "0.3" "0.3" ];
      dark-mscolor = [ "0.3" "0.3" "0.3" ];
      smbgcolor = [ "0.15" "0.15" "0.15" ];
      dark-smbgcolor = [ "0.15" "0.15" "0.15" ];
      bartype = "Mainland";
      bradius = 0.0;
      bwidth = 0.0;
      height = 26.0;
      margin = 0.0;
      vpad = -0.0;
      neon = false;
      autotheme-font = false;
      font = "Noto Sans ExtraCondensed SemiBold 12";
      fgalpha = 0.66;
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
