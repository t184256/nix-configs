{ config, pkgs, ... }:

{
  imports = [ ../config/language-support.nix ];
  programs.nixvim = {
    options = {
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
    plugins.rainbow-delimiters = {
      enable = config.language-support != [];
      highlight = [
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
    '';
  };
}
