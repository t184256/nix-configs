{ config, ... }:

{
  imports = [
    ../config/language-support.nix
    ../config/neovim.nix
  ];
  programs.nixvim = if (! config.neovim.fat) then {} else {
    # fancy plugins: treesitter
    plugins.treesitter = {
      # playground  # :TSHighlightCapturesUnderCursor,
                    # :help treesitter-highlight-groups
      enable = config.language-support != [];
      moduleConfig.highlight = {
        enable = true;
        indent = true;
        #additional_vim_regex_highlighting = false;
      };
      #vim.api.nvim_set_hl(0, "@none", { link = "Normal" })
    };
    plugins.treesitter-context = {
      enable = true;
      settings = {
        separator = "─";
        mode = "topline";
        min_window_height = 36;
        max_lines = 3;
        trim_scope = "inner";
      };
    };
  };
}
