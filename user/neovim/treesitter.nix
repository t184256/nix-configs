{ config, ... }:

{
  programs.nixvim.plugins.treesitter = {
    # fancy plugins: treesitter
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
}
