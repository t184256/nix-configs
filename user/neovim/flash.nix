{ config, ... }:

let
  lua = config.nixvim.helpers.mkRaw;
  colemak = "esiroantdhwyfuqglxcvzkbse";
in
{
  programs.nixvim = {
    plugins.flash = {
      enable = true;  # search with hops
      labels = colemak;
      jump.autojump = true;
      highlight.groups.label = "JumpLabel";
      prompt.prefix = [ ["s" "Comment"] ];
      modes = {
        treesitter = {
          labels = colemak;
          label.rainbow.enabled = true;
          label.rainbow.shade = 9;
        };
        search.label.style = "eol";
      };
    };
    keymaps = [
      {
        key = "s";
        mode = "n";
        action = lua "function() require('flash').jump() end";
      }
      {
        key = "S";
        mode = "n";
        action = lua "function() require('flash').treesitter() end";
      }
    ];
  };
}
