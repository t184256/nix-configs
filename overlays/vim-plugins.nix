self: super:

{
  vimPlugins = super.vimPlugins // {
    vim-boring = super.pkgs.vimUtils.buildVimPluginFrom2Nix {
      pname = "vim-boring";
      version = "20230915";
      src = super.fetchFromGitHub {
        owner = "t184256";
        repo = "vim-boring";
        rev = "06275563140b4e64fc5dd7bd37ac5f3a248c4c5f";
        sha256 = "sha256-WSor/hJFYY09tYgWQl7R+Wz9D4ZBI12omDT9f30dr5s=";
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

    actions-preview = super.pkgs.vimUtils.buildVimPluginFrom2Nix {
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
