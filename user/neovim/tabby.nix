{ pkgs, config, ... }:

{
  imports = [
    ../config/language-support.nix
    ../config/neovim.nix
  ];
  programs.nixvim = if (! config.neovim.fat) then {} else {
    extraPlugins = with pkgs.vimPlugins; [
      vim-tabby
    ];
    extraConfigLua = ''
      vim.g.tabby_trigger_mode = 'manual'
      vim.g.tabby_keybinding_accept = '<C-Space>'
      vim.g.tabby_keybinding_trigger_or_dismiss = '<C-_>'
    '';
  };
  home.wraplings = if (! config.neovim.fat) then {} else {
    ai = "nvim '+lua vim.g.tabby_trigger_mode = \"auto\"'";
  };
}
