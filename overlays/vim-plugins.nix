self: super:

{
  vimPlugins = super.vimPlugins // {
    vim-boring = super.pkgs.vimUtils.buildVimPlugin {
      pname = "vim-boring";
      version = "2024-02-29";
      src = super.fetchFromGitHub {
        owner = "t184256";
        repo = "vim-boring";
        rev = "01b73de80d366fd63c977f8b8ae5f0e359b34ae0";
        sha256 = "sha256-298/NfFNpl0sNpw64yrBLDarf+7H20IvY9MpHMZ+WE8=";
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
      version = "2024-02-25";
      src = super.fetchFromGitHub {
        owner = "aznhe21";
        repo = "actions-preview.nvim";
        rev = "5c240e6356156b72cfbf7c05feefadae61d7a06f";
        sha256 = "sha256-XJxwKusvtKvLdtvOjLwmwCP09djhjm9DqL4C1Eca4oY=";
      };
    };

    deadcolumn = super.pkgs.vimUtils.buildVimPlugin rec {
      pname = "deadcolumn";
      version = "1.0.0";
      src = super.fetchFromGitHub {
        owner = "Bekaboo";
        repo = "deadcolumn.nvim";
        rev = "v${version}";
        sha256 = "sha256-SWjXeu6d22T+naYvYPdnU8V2L0K7QviHo1B5GIG6r1k=";
      };
    };

    shipwright = super.pkgs.vimUtils.buildVimPlugin rec {
      pname = "shipwright";
      version = "2022-01-07";
      src = super.fetchFromGitHub {
        owner = "rktjmp";
        repo = "shipwright.nvim";
        rev = "ab70e80bb67b7ed3350bec89dd73473539893932";
        sha256 = "sha256-Gy0tIqH1dmZgcUvrUcNrqpMXi3gOgHq9X1SbjIZqSns=";
      };
    };
  };
}
