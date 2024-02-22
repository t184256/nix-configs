self: super:

{
  vimPlugins = super.vimPlugins // {
    vim-boring = super.pkgs.vimUtils.buildVimPlugin {
      pname = "vim-boring";
      version = "20230915";
      src = super.fetchFromGitHub {
        owner = "t184256";
        repo = "vim-boring";
        rev = "d84ffb495a9ed357a8722b0574333ed3b07845a2";
        sha256 = "sha256-PFxoqqiJLuzSbSDA1rMAaGaY5WPIHPjsXv+oOOAUjaU=";
      };
    };

    vim-undofile-warn = super.pkgs.vimUtils.buildVimPlugin {
      pname = "undofile-warn";
      version = "1.3";
      src = super.fetchFromGitHub {
        owner = "Carpetsmoker";
        repo = "undofile_warn.vim";
        rev = "version-1.3";
        sha256 = "1sxq5gxyw7y3rb74j94jsl6k06klrvc0kijcxcjwd11kb6gnrs2a";
      };
    };

    actions-preview = super.pkgs.vimUtils.buildVimPlugin {
      pname = "actions-preview";
      version = "2023-05-12";
      src = super.fetchFromGitHub {
        owner = "aznhe21";
        repo = "actions-preview.nvim";
        rev = "3028c9a35853bb5fb77670fb58537ce28085329c";
        sha256 = "sha256-mkLn2/klAdirbqxJ3xLz2vyjEx4Sb0NLEK/LS2w8rag=";
      };
    };
  };
}
