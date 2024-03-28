{ config, pkgs, ... }:

let
  withLang = lang: builtins.elem lang config.language-support;
in
{
  nixpkgs.overlays = [ (import ../../overlays/vim-plugins.nix) ];

  imports = [
    ../config/language-support.nix
    ../config/neovim.nix
    ./classic-plugins.nix
    ./colorcolumn.nix
    ./colorscheme.nix
    ./completion.nix
    ./flash.nix
    ./gitmessenger.nix
    ./gitsigns.nix
    ./indent-guides.nix
    ./languages.nix
    ./noice.nix
    ./tabby.nix
    ./title.nix
    ./treesitter.nix
    ./vimagit.nix
    ./zen.nix
  ];

  programs.nixvim = {
    enable = true;
    viAlias = true;

    options = {
      shell = "/bin/sh";

      ruler = false;
      showmode = false;

      scrolloff = 3;
    };

    extraPlugins = with pkgs.vimPlugins; [
    ];

    extraConfigLuaPost = ''
      vim.opt.diffopt = vim.opt.diffopt + 'algorithm:patience'
      vim.opt.suffixes = vim.opt.suffixes + '.pdf'
    '';
  };

  home.wraplings.view = "nvim -R";
  home.sessionVariables.EDITOR = "nvim";
}
