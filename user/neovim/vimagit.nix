{ pkgs, ... }:

{
  programs.nixvim = {
    extraPlugins = with pkgs.vimPlugins; [
      vimagit  # no longer my preferred git interface for committing
    ];
    globals.magit_autoclose = 1;
  };
  home.wraplings.try-not-to-use-vimagit = "nvim +MagitOnly";
}
