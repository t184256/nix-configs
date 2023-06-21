{ ... }:

{
  programs.nixvim = {
    # display statusline if there are at least two windows
    options.laststatus = 1;

    # TODO: make mini popups pop up one line lower
    plugins.noice = {
      enable = true;
      lsp.signature.enabled = true;
      cmdline.view = "cmdline";
      cmdline.format = {
        cmdline = { icon = false; conceal = false; };
        search_down = { icon = false; conceal = false; };
        search_up = { icon = false; conceal = false; };
        filter = { icon = false; conceal = false; };
        lua = { icon = false; conceal = false; };
        help = { icon = false; conceal = false; };
      };
      lsp.progress.enabled = false;
      lsp.signature.view = "virtualtext";
      lsp.hover.view = "virtualtext";
      lsp.documentation.view = "virtualtext";
      views.mini.position.row = "100%";
      # replace confirmation shouldn't obscure the text it's asking about
      routes = [{
        view = "cmdline";
        filter.any = [ { event = "msg_show"; kind = "confirm_sub"; } ];
      }];
    };
  };
}
