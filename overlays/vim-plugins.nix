self: super:

{
  vimPlugins = super.vimPlugins // {
    vim-boring = super.pkgs.vimUtils.buildVimPlugin {
      pname = "vim-boring";
      version = "unstable-2024-03-28";
      src = super.fetchFromGitHub {
        owner = "t184256";
        repo = "vim-boring";
        rev = "1090b4bde142fbb2f5c9c5cfa08238c5eaeceb2f";
        sha256 = "1r4qgvzd0s94irwp8kv0gbjn4f04hvyk151bz8lysq8xcj2k7m8v";
      };
      nativeBuildInputs = [ super.pkgs.vimPlugins.lush-nvim ];
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
