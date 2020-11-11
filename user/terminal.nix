{ config, pkgs, ... }:

let
  baseSettings = {
    env = { TERM = "xterm-256color"; };
    window.padding = { x = 0; y = 0; };
    dynamic_padding = true;  # I don't think it works
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
    mouse.hide_when_typing = true;
    selection.save_to_clipboard = true;
    live_config_reload = false;
  };
in
{
  programs.alacritty = {
    enable = true;
    settings = baseSettings;
  };

  # TODO: 640, 1280, 2560
  xdg.configFile."alacritty/alacritty-960.yml".text =
    builtins.toJSON (baseSettings // { font = {
      size = 24;
      offset = { x = -2; y = -2; };
      glyph_offset = { x = -1; y = -1; };
    };});
  xdg.configFile."alacritty/alacritty-1920.yml".text =
    builtins.toJSON (baseSettings // { font = {
      size = 48;
      offset = { x = -4; y = -2; };
      glyph_offset = { x = -2; y = -1; };
    };});

  home.wraplings =
    let
      hopper = "--class TermHopper -e ~/.tmux-hopper.sh";
      config = w: "--config-file ~/.config/alacritty/alacritty-${toString w}.yml";
      mkWidth = w: {
        "term-${toString w}" = "alacritty ${config w}";
        "term-hopper-${toString w}" = "alacritty ${config w} ${hopper}";
      };
    in
    {
      term = "alacritty";
      term-hopper = "alacritty ${hopper}";
    } // (mkWidth 960)
      // (mkWidth 1920);
}
