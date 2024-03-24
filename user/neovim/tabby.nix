{ pkgs, ... }:

{
  programs.nixvim = {
    extraPlugins = with pkgs.vimPlugins; [
      vim-tabby
    ];
    extraConfigLua = ''
      vim.g.tabby_trigger_mode = 'manual'
      vim.g.tabby_keybinding_accept = '<C-Space>'
      vim.g.tabby_keybinding_trigger_or_dismiss = '<C-_>'
    '';
  };
  home.wraplings.ai = "nvim '+lua vim.g.tabby_trigger_mode = \"auto\"'";
}
