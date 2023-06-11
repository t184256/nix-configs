{ pkgs, ... }:

{
  programs.nixvim = {
    extraPlugins = with pkgs.vimPlugins; [
      vimagit  # my preferred git interface for committing
    ];
    globals.magit_autoclose = 1;
  };
  home.wraplings.vimagit = "nvim +MagitOnly";
}
