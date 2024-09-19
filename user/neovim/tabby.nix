{ pkgs, config, ... }:

{
  imports = [
    ../config/language-support.nix
    ../config/neovim.nix
  ];
  programs.nixvim = if (! config.neovim.fat) then {} else {
    extraPlugins = with pkgs.vimPlugins; [
      {
        plugin = vim-tabby;
        optional = true;
      }
    ];
    extraConfigLua = ''
      if (vim.g.with_tabby == 1) then
        vim.g.tabby_trigger_mode = 'auto'
        vim.g.tabby_keybinding_accept = '<C-Space>'
        vim.g.tabby_keybinding_trigger_or_dismiss = '<C-_>'
        vim.api.nvim_command ":packadd vim-tabby"
      end
    '';
  };
  home.wraplings = if (! config.neovim.fat) then {} else {
    ai = "nvim --cmd 'lua vim.g.with_tabby = 1'";
  };
}
