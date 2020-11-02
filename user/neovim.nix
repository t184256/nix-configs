{ config, pkgs, lib, ... }:

let
  withLang = lang: builtins.elem lang config.language-support;
in
{
  programs.neovim = {
    enable = true;

    withPython = false;  # it's 2020!
    withRuby = false;
    #withNodeJs = true;

    extraPackages = with pkgs; [
    ] ++ lib.optionals (withLang "bash") [
      shellcheck
    ] ++ lib.optionals (withLang "python") [
      (python3Packages.python-language-server.override {
        providers = [ "autopep" "mccabe" "pycodestype" "pydocstyle"
                      "pyflakes" "yapf"];
      })
      python3Packages.isort
      python3Packages.yapf
    ];
    extraPython3Packages = (ps: with ps; [
    ] ++ lib.optionals (withLang "python") [
    ]);

    plugins = with pkgs.vimPlugins; [
      vim-eunuch  # helpers for UNIX: :SudoWrite, :Rename, ...
      vim-lastplace  # remember position
      vim-nix  # syntax files and indentation
      vim-repeat  # better repetition
      vim-sleuth  # guess indentation
      tcomment_vim  # <gc> comment action
      vim-undofile-warn   # undofile enabled + warning on overundoing
      {
        plugin = vim-better-whitespace;  # trailing whitespace highlighting
        config = ''
          let g:show_spaces_that_precede_tabs = 1
	'';
      }
      {
        plugin = vim-easymotion;  # faster motion bound to <s>
        config = ''
          nmap s <Plug>(easymotion-overwin-f)
          let g:EasyMotion_smartcase = 1
          let g:EasyMotion_keys="tnaowyfu'x.c,rise"  " combos start with last
	'';
      }
      {
        plugin = vim-indent-guides;  # indent guides
        config = ''
          let g:indent_guides_enable_on_vim_startup = 1
          let g:indent_guides_auto_colors = 0
          autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd  guibg='#000000'
          autocmd VimEnter,Colorscheme * :hi IndentGuidesEven guibg='#121212'
        '';
      }
      {
	plugin = vim-monotone;  # non-clownish color theme
        config = ''
          let &t_8f="\<Esc>[38;2;%lu;%lu;%lum"
          let &t_8b="\<Esc>[48;2;%lu;%lu;%lum"
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
      {
        plugin = vimagit;  # my preferred git interface for committing
        config = ''
          let g:magit_auto_close = 1
        '';
      }
    ];

    extraConfig = ''
      set shell=/bin/sh
      set laststatus=1  " display statusline if there are at least two windows
      set suffixes+=.pdf  " don't offer to open pdfs
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
