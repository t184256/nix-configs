{ pkgs, ... }:

{
  programs.nixvim.plugins.treesitter = {
    # fancy plugins: treesitter
    # playground  # :TSHighlightCapturesUnderCursor,
                  # :help treesitter-highlight-groups
    enable = true;
    moduleConfig.highlight = {
      enable = true;
      #additional_vim_regex_highlighting = false;
    };
    #vim.api.nvim_set_hl(0, "@none", { link = "Normal" })
  };
}
