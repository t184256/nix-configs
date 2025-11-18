{ config, pkgs, inputs, ... }:

let
  nixGLMaybe = (
    if config.system.os == "OtherLinux"
    then "${pkgs.nixgl.nixGLIntel}/bin/nixGLIntel"
    else ""
  );

  alacritty-autoresizing =
    inputs.alacritty-autoresizing.defaultPackage.${pkgs.stdenv.hostPlatform.system};

  baseSettings = {
    env = { TERM = "alacritty"; };
    window.padding = { x = 0; y = 0; };
    window.dynamic_padding = true;
    window.startup_mode = "Maximized";
    font = {
      alt.family = "Iosevka Term Light";
      alt_italic = { family = "Iosevka Term Light"; style = "Italic"; };
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
    general = {
      live_config_reload = false;
    };

    # Gotta love GNOME 40. What do they smoke, huh?
    # lack of server-side decorations, mouse never reappearing...
    window.decorations = "None";  # CSD is unusable with touch or stylus anyway
  };

in

{
  nixpkgs.overlays = [ (import ../overlays/alacritty) ];

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
    term-hopper = "${term} --class Console,Console -e ~/.tmux-hopper.sh";
  };

  xdg.desktopEntries = if config.system.noGraphics then {} else {
    term = {
      name = "Term";
      genericName = "Term";
      icon = "org.gnome.Console";
      exec = "term";
      terminal = false;
      categories = [ "TerminalEmulator" ];
    };
    console = {
      name = "Console";
      genericName = "Console";
      icon = "org.gnome.Console";
      exec = "term-hopper";
      terminal = false;
      categories = [ "TerminalEmulator" ];
    };
  };
}
