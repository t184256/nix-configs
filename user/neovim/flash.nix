_:

let
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
        action = "function() require('flash').jump() end";
        lua = true;
      }
      {
        key = "S";
        mode = "n";
        action = "function() require('flash').treesitter() end";
        lua = true;
      }
    ];
  };
}
