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
      if (vim.g.with_tabby ~= 1) then
        vim.g.tabby_trigger_mode = 'auto'
        vim.g.tabby_keybinding_accept = '<C-Space>'
        vim.g.tabby_keybinding_trigger_or_dismiss = '<C-_>'
      else
        vim.g.loaded_tabby = 0  -- any value prevents loading
      end
    '';
  };
  home.wraplings = if (! config.neovim.fat) then {} else {
    ai = "nvim '+lua vim.g.want_tabby = 1'";
  };
}
