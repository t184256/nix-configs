self: super:

{
  vimPlugins = super.vimPlugins // {
    vim-monotone = super.pkgs.vimUtils.buildVimPluginFrom2Nix {
      pname = "vim-monotone";
      version = "2020719";
      src = super.fetchFromGitHub {
        owner = "Lokaltog";
        repo = "vim-monotone";
        rev = "5393343ff2d639519e4bcebdb54572dfe5c35686";
        sha256 = "0wyz5biw6vqgrlq1k2354mda6r36wga30rjaj06div05k3g7xhq4";
      };
    };

    vim-undofile-warn = super.pkgs.vimUtils.buildVimPluginFrom2Nix {
      pname = "undofile-warn";
      version = "1.3";
      src = super.fetchFromGitHub {
        owner = "Carpetsmoker";
        repo = "undofile_warn.vim";
        rev = "version-1.3";
        sha256 = "1sxq5gxyw7y3rb74j94jsl6k06klrvc0kijcxcjwd11kb6gnrs2a";
      };
    };
  };
}
