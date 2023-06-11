{ pkgs, ... }:

{
  programs.nixvim = {
    plugins.gitmessenger = {
      enable = true;  # git blame from within vim
    };
    # in addition to default "gm", let's see what gets used
    maps.normal."gb" = {
      silent = true;
      action = "<Plug>(git-messenger)";
    };
  };
}
