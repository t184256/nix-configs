{ config, pkgs, lib, inputs, ... }:

let
  withLang = lang: builtins.elem lang config.language-support;
in
{
  nixpkgs.overlays = [ (import ../../overlays/vim-plugins.nix) ];

  imports = [
    ./classic-plugins.nix
    ./completion.nix
    ./colorcolumn.nix
    ./colorscheme.nix
    ./gitmessenger.nix
    ./gitsigns.nix
    ./indent-guides.nix
    ./languages.nix
    ./noice.nix
    ./title.nix
    ./treesitter.nix
    ./vimagit.nix
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
