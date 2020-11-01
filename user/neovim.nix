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
      vim-undofile-warn   # undofile enabled + warning on overundoing
      vimagit  # my preferred git interface for committing
      {
        plugin = vim-easymotion;  # faster motion bound to <s>
        config = ''
          nmap s <Plug>(easymotion-overwin-f)
          let g:EasyMotion_smartcase = 1
          let g:EasyMotion_keys="tnaowyfu'x.c,rise"  " combos start with last
	'';
      }
      {
	plugin = vim-monotone;  # non-clownish color theme
        config = ''
          set termguicolors
          let g:monotone_color = [0, 0, 100]
          let g:monotone_contrast_factor = 1
          "let g:monotone_secondary_hue_offset = 200
          let g:monotone_emphasize_whitespace = 1
          colorscheme monotone
          hi MatchParen gui=reverse
          hi EndOfBuffer guifg=#303030
          hi normal guibg=black
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
