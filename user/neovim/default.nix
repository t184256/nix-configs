{ config, pkgs, lib, ... }:

let
  withLang = lang: builtins.elem lang config.language-support;
in
{
  nixpkgs.overlays = [ (import ../../overlays/vim-plugins.nix) ];

  imports = [
    ../config/language-support.nix
    ../config/neovim.nix
    ../config/no-graphics.nix
    ./aider.nix
    ./minuet.nix
    ./classic-plugins.nix
    ./colorcolumn.nix
    ./colorscheme.nix
    ./completion.nix
    ./flash.nix
    ./gitcommit.nix
    ./gitmessenger.nix
    ./gitsigns.nix
    ./indent-guides.nix
    ./languages.nix
    ./llm-commit-msg.nix
    ./neogit.nix
    ./noice.nix
    ./nvim-ufo.nix
    ./oil.nix
    ./selection.nix
    ./smart-langmap.nix
    ./title.nix
    ./treesitter.nix
    ./vimagit.nix
    ./zen.nix
  ];

  programs.nixvim = {
    version.enableNixpkgsReleaseCheck = false;  # FIXME: remove in 2026
    enable = true;
    viAlias = true;

    withRuby = false;  # one radical way to skip loading notmuch plugin

    # Disable runtimes on headless or slim setups
    withPython3 = lib.mkMerge [
      (lib.mkForce false)
      (lib.mkIf (config.neovim.fat && ! config.system.noGraphics) true)
    ];
    withNodeJs = lib.mkMerge [
      (lib.mkForce false)
      (lib.mkIf (config.neovim.fat && ! config.system.noGraphics) true)
    ];
    waylandSupport = lib.mkMerge [
      (lib.mkForce false)
      (lib.mkIf (config.neovim.fat && ! config.system.noGraphics) true)
    ];

    opts = {
      shell = "/bin/sh";

      ruler = false;
      showmode = false;

      scrolloff = 3;
    };

    extraPlugins = with pkgs.vimPlugins; [
    ];

    extraConfigLua = ''
      vim.api.nvim_command('aunmenu PopUp.How-to\\ disable\\ mouse')
      vim.api.nvim_command('aunmenu PopUp.-2-')
    '';
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
