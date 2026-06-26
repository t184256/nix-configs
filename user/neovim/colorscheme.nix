{ config, pkgs, lib, ... }:

{
  imports = [
    ../config/language-support.nix
    ../config/neovim.nix
  ];
  programs.nixvim = {
    opts = {
      termguicolors = true;
      wildoptions = "pum";
      pumblend = 20;
      winblend = 20;
    };
    colorscheme = "boring";
    extraPlugins = with pkgs.vimPlugins; [
      vim-boring  # my non-clownish color theme
      lush-nvim
      #shipwright
    ];
    plugins.rainbow-delimiters = lib.mkIf config.neovim.fat {
      enable = true;
      settings.highlight = [
        "RainbowDelimiterCyan"  # is, actually, grey
        "RainbowDelimiterBlue"
        "RainbowDelimiterYellow"
        "RainbowDelimiterGreen"  # not very noticeable
        "RainbowDelimiterOrange"
        "RainbowDelimiterViolet"
        "RainbowDelimiterRed"
      ];
    };
    # https://github.com/rktjmp/lush.nvim/issues/142
    extraConfigLua = ''
      vim.cmd('highlight Comment gui=altfont');
      vim.cmd('highlight Keyword gui=altfont');
      vim.cmd('highlight diffFile gui=altfont');
      vim.cmd('highlight diffIndexLine gui=altfont');
      vim.cmd('highlight diffLine gui=altfont');
      vim.cmd('highlight diffNewFile gui=altfont');
      vim.cmd('highlight diffOldFile gui=altfont');
      vim.cmd('highlight DiagnosticError gui=altfont');
      vim.cmd('highlight DiagnosticWarn gui=altfont');
      vim.cmd('highlight DiagnosticInfo gui=altfont');
      vim.cmd('highlight DiagnosticHint gui=altfont');
      vim.cmd('highlight DiagnosticOK gui=altfont');
      vim.cmd('highlight JumpLabel gui=altfont');
      vim.cmd('highlight NoiceMini gui=altfont');
      vim.cmd('highlight TreesitterContext gui=altfont');
      vim.cmd('highlight TreesitterContextSeparator gui=altfont');
      vim.cmd('highlight UfoFoldedEllipsis gui=altfont');

      -- Minuet duet preview highlights
      vim.cmd('highlight MinuetDuetCursor guibg=#c0a0c0 guisp=#c0a0c0 gui=undercurl');
      vim.cmd('highlight MinuetDuetAdd guifg=#c0a0c0 gui=altfont');
      vim.cmd('highlight MinuetDuetDelete guisp=#c0a0c0 gui=strikethrough');
      vim.cmd('highlight MinuetDuetPlaceHint guisp=#c0a0c0 gui=undercurl');
      vim.cmd('highlight MinuetDuetReplace guisp=#c0a0c0 gui=underline,strikethrough');
      vim.cmd('highlight MinuetDuetComment guifg=#babdb6 gui=italic,dim,altfont');
    '';
  };
}
