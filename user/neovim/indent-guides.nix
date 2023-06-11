# see also gitgutter.nix
{ pkgs, ... }:

{
  programs.nixvim = {
    extraPlugins = with pkgs.vimPlugins; [
      vim-indent-guides  # indent guides
    ];
    globals = {
      indent_guides_enable_on_vim_startup = 1;
      indent_guides_auto_colors = 0;
    };
    # TODO: could it work w/o autocmd?
    autoCmd = [
      {
        event = [ "VimEnter" "Colorscheme" ];
        command = ":hi IndentGuidesOdd guibg=#000000";
      }
      {
        event = [ "VimEnter" "Colorscheme" ];
        command = ":hi IndentGuidesEven guibg=#0e0e0e";
      }
    ];
  };
}
