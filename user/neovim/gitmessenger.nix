_:

{
  programs.nixvim = {
    plugins.gitmessenger = {
      enable = true;  # git blame from within vim
    };
    # in addition to default "gm", let's see what gets used
    keymaps = [{
      key = "gb";
      mode = "n";
      action = "<Plug>(git-messenger)";
      options.silent = true;
    }];
  };
}
