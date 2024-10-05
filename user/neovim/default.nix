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
    ./mark-radar.nix
    ./neogit.nix
    ./noice.nix
    ./nvim-ufo.nix
    ./oil.nix
    ./selection.nix
    ./smart-langmap.nix
    ./tabby.nix
    ./title.nix
    ./treesitter.nix
    ./vimagit.nix
    ./zen.nix
  ];

  programs.nixvim = {
    enable = true;
    viAlias = true;

    withRuby = false;  # one radical way to skip loading notmuch plugin

    opts = {
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

    luaLoader.enable = true;
    performance = {
      byteCompileLua = {
        enable = true;
        configs = true;
        initLua = true;
        nvimRuntime = true;
        plugins = true;
      };
      combinePlugins = {
        enable = true;
        standalonePlugins = [ "vimagit" "nvim-treesitter" ];
      };
    };
  };

  home.wraplings.view = "nvim -R";
  home.sessionVariables.EDITOR = "nvim";
}
