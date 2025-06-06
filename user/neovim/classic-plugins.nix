{ pkgs, ... }:

{
  programs.nixvim = {
  # TODO: look into lua alternatives
    plugins = {
      lastplace.enable = true;  # remember position
      fugitive.enable = true;  # mostly as a gv dependency
      comment.enable = true;  # <gc> comment action
    };
    extraPlugins = with pkgs.vimPlugins; [
      # less fancy plugins from classical vim world
      vim-eunuch  # helpers for UNIX: :SudoWrite, :Rename, ...
      vim-nix  # syntax files and indentation
      vim-repeat  # better repetition
      guess-indent-nvim  # guess indentation, in Lua
      vim-undofile-warn   # undofile enabled + warning on overundoing
      vim-gnupg  # transparent editing of .gpg files

      # gv and its dependencies
      gv-vim vim-rhubarb fugitive-gitlab-vim  # and vim-fugutive

      # those that need some configuration
      vim-better-whitespace  # trailing whitespace highlighting
    ];
    globals = {
      show_spaces_that_precede_tabs = 1;
    };
    extraConfigLua = ''
      require('guess-indent').setup {}
    '';
  };
}
