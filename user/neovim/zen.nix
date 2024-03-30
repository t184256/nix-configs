_:

{
  programs.nixvim = {
    # Disabled, nixvim update is needed
    plugins.zen-mode = {
      enable = true;
      settings = {
        window = {
          backdrop = 1;
          width = 80;
        };
        on_open = ''
          function(win)
            require("noice").cmd("disable")
            vim.diagnostic.config({virtual_text = false})
            vim.cmd('highlight ColorColumn guibg=#000000');
          end
        '';
        on_close = ''
          function(win)
            vim.diagnostic.config({virtual_text = true})
            require("noice").cmd("enable")
          end
        '';
      };
    };
    plugins.twilight = {
      enable = true;
      settings.dimming.alpha = 0.30;
      settings.dimming.inactive = true;
    };
    keymaps = [
      {
        key = "<space>z";
        mode = "n";
        action = "function() require('zen-mode').toggle({}) end";
        lua = true;
      }
    ];
  };
}
