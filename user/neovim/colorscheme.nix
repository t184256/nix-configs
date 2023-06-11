{ pkgs, ... }:

{
  programs.nixvim = {
    options = {
      termguicolors = true;
      wildoptions = "pum";
      pumblend = 20;
      winblend = 20;
      colorcolumn = "80";
    };
    colorscheme = "boring";
    extraPlugins = with pkgs.vimPlugins; [
      vim-boring  # my non-clownish color theme
    ];
    highlight = {
      ColorColumn = { fg = "#ddbbbb"; bg = "#0a0a0a"; };
      Pmenu = { fg = "#aaaaaa"; };
    };
    # old comment: fix nested highlighting problems with hard overrides
  };
}
