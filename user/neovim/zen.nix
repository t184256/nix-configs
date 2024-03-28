_:

{
  programs.nixvim = {
    # Disabled, nixvim update is needed
    #plugins.zen-mode = {
    #  enable = true;
    #};
    plugins.twilight = {
      enable = true;
      settings.dimming.alpha = 0.30;
      settings.dimming.inactive = true;
    };
    keymaps = [
      # wired to twilight and not zen-mode, nixvim update is neeeded
      #{
      #  key = "<space>z";
      #  mode = "n";
      #  action = "function() require('zen-mode').toggle({}) end";
      #  lua = true;
      #}
      {
        key = "<space>z";
        mode = "n";
        action = "<cmd>Twilight<cr>";
      }
    ];
  };
}
