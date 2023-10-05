# see also indent-guides.nix
_:

{
  programs.nixvim = {
    plugins.gitgutter = {
      enable = true;  # color changed lines
      # don't show signs column and don't highlight until I press <gl>
      signsByDefault = false;
    };
    globals.gitgutter_highlight_lines = 0;
    options.signcolumn = "no";
    keymaps = [{
      key = "gl";
      mode = "n";
      action = ":GitGutterLineHighlightsToggle<CR>:IndentGuidesToggle<CR>";
      options.silent = true;
    }];
    autoCmd = [
      { event = [ "BufWritePost" ]; command = "GitGutter"; }
      # TODO: could that be done without autocmd?
      {
        event = [ "VimEnter" "Colorscheme" ];
        command = ":hi GitGutterAddLine guibg=#002200";
      }
      {
        event = [ "VimEnter" "Colorscheme" ];
        command = ":hi GitGutterChangeLine guibg=#222200";
      }
      {
        event = [ "VimEnter" "Colorscheme" ];
        command = ":hi GitGutterDeleteLine guibg=#220000";
      }
      {
        event = [ "VimEnter" "Colorscheme" ];
        command = ":hi GitGutterChangeDeleteLine guibg=#220022";
      }
    ];
  };
}
