{ config, pkgs, ... }:

{
  programs.neovim = {
    enable = true;

    withPython = false;  # it's 2020!
    withRuby = false;
    #withNodeJs = true;

    extraPackages = with pkgs; [];
    extraPython3Packages = (ps: with ps; []);

    plugins = with pkgs.vimPlugins; [
      vim-eunuch  # helpers for UNIX: :SudoWrite, :Rename, ...
      vim-lastplace  # remember position
      vim-nix  # syntax files and indentation
      vimagit  # my preferred git interface for committing
      {
        plugin = vim-easymotion;
        # faster motion bound to <s>
        config = ''
          nmap s <Plug>(easymotion-overwin-f)
          let g:EasyMotion_smartcase = 1
          let g:EasyMotion_keys="tnaowyfu'x.c,rise"  " combos start with last
	'';
      }
    ];

    extraConfig = ''
      set shell=/bin/sh
      set laststatus=1  " display statusline if there are at least two windows
      nnoremap <C-L> :nohlsearch<CR><C-L>  " clear search highlighting
    '';

    viAlias = true;
  };

  home.wraplings = {
    view = "nvim -R";
    vimagit = "nvim +MagitOnly";
  };
  home.sessionVariables.EDITOR = "nvim";
}
