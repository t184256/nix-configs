{ config, pkgs, inputs, ... }:

let
  nixGLMaybe = (
    if config.system.os == "OtherLinux"
    then "${pkgs.nixgl.nixGLIntel}/bin/nixGLIntel"
    else ""
  );

  alacritty-autoresizing =
    inputs.alacritty-autoresizing.defaultPackage.${pkgs.system};

  baseSettings = {
    env = { TERM = "xterm-256color"; };
    window.padding = { x = 0; y = 0; };
    window.dynamic_padding = true;
    font = {
      normal.family = "Iosevka Term";
      bold = { family = "Iosevka Term Medium"; style = "Normal"; };
      size = 24;
      # small y offsetting as iosevka-t184256 has custom -25% line spacing
      offset = { x = -2; y = -2; };
      glyph_offset = { x = -1; y = -1; };
    };
    colors.primary = { background = "#000000"; foreground = "#ffffff"; };
    bell = { animation = "EaseOutExpo"; duration = 100; color = "#7f7f7f"; };
    selection.save_to_clipboard = true;
    live_config_reload = false;

    # Gotta love GNOME 40. What do they smoke, huh?
    # lack of server-side decorations, mouse never reappearing...
    mouse.hide_when_typing = false;  # broken
    window.decorations = "none";  # CSD is unusable with touch or stylus anyway
    window.startup_mode = "maximized";
    gtk_theme_variant = "dark";
  };

in

{
  imports = [ ./config/no-graphics.nix ];

  programs.alacritty = if config.system.noGraphics then {} else {
    enable = true;
    settings = baseSettings;
  };

  xdg.configFile = if config.system.noGraphics then {} else {
    "alacritty/autoresizing.cfg.py".source =
      "${inputs.alacritty-autoresizing}/autoresizing.cfg.py";
  };

  home.wraplings = if config.system.noGraphics then {} else rec {
    term = "${nixGLMaybe} ${alacritty-autoresizing}/bin/alacritty-autoresizing";
    term-hopper = "${term} --class term-hopper,Console -e ~/.tmux-hopper.sh";
  };

  xdg.dataFile = if config.system.noGraphics then {} else {
    "applications/term.desktop".text = ''
      [Desktop Entry]
      Categories=TerminalEmulator;
      Exec=term
      GenericName=Term
      Icon=org.gnome.Terminal
      Name=Term
      Terminal=false
      Type=Application
    '';
    "applications/console.desktop".text = ''
      [Desktop Entry]
      Categories=TerminalEmulator;
      Exec=term-hopper
      GenericName=Console
      Icon=org.gnome.Console
      Name=Console
      Terminal=false
      Type=Application
    '';
  };
  # TODO: in 21.11, use
  # xdg.desktopEntries = {
  #   term = {
  #     name = "Term";
  #     genericName = "Term";
  #     icon = "org.gnome.Terminal";
  #     exec = "term";
  #     terminal = false;
  #     categories = [ "TerminalEmulator" ];
  #   };
  # };
}
