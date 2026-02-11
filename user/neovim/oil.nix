_:

{
  programs.nixvim = {
    plugins.oil = {
      enable = true;
    };
    #plugins.mini-icons.enable = true;
    keymaps = [
      {
        mode = "n";
        key = "-";
        action = "<CMD>Oil<CR>";
      }
    ];
  };
}
