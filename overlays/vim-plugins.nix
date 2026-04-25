self: super:

rec {
  luajit = super.luajit.override {
    packageOverrides = luaself: luaprev: {
      #neotest = luaprev.neotest.overrideAttrs (oa: {
      #  doCheck = false;
      #});
      lush-nvim = luaprev.lush-nvim.overrideAttrs (oa: {
      postInstall = ''
        rm -vf $out/lush.nvim-*/lush.nvim/scm-1/examples/lush-template/README.md
      '';
      });
    };
  };
  luajitPackages = luajit.pkgs;

  vimPlugins = super.vimPlugins.extend ( final: prev: {
    neogit = prev.neogit.overrideAttrs (oa: {
      postPatch = (oa.postPatch or "") + ''
        # fewer useless lines in the git commit buffer
        substituteInPlace lua/neogit/buffers/editor/init.lua \
          --replace-fail \
            "local help_lines = {" \
            "local help_lines = {}; local _ = {"
        # disable forced nowrapping that I don't vibe with
        substituteInPlace lua/neogit/lib/buffer.lua \
          --replace-fail \
            'vim.wo[winid].wrap = false' \
            '-- vim.wo[winid].wrap = false' \
          --replace-fail \
            'buffer:set_window_option("wrap", false)' \
            '-- buffer:set_window_option("wrap", false)'
      '';
    });

    lush-nvim = prev.lush-nvim.overrideAttrs (oa: {
      postInstall = ''
        rm -vf $out/lush.nvim-*/lush.nvim/scm-1/examples/lush-template/README.md
      '';
    });
    vim-boring = super.pkgs.vimUtils.buildVimPlugin {
      pname = "vim-boring";
      version = "unstable-2024-03-28";
      src = super.fetchFromGitHub {
        owner = "t184256";
        repo = "vim-boring";
        rev = "1090b4bde142fbb2f5c9c5cfa08238c5eaeceb2f";
        sha256 = "1r4qgvzd0s94irwp8kv0gbjn4f04hvyk151bz8lysq8xcj2k7m8v";
      };
      nativeBuildInputs = [ self.pkgs.vimPlugins.lush-nvim ];
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
      version = "1.0.2";
      src = super.fetchFromGitHub {
        owner = "Bekaboo";
        repo = "deadcolumn.nvim";
        rev = "v${version}";
        sha256 = "sha256-/EtRvosijeVAMa7vQhcrFRkOs+gslDUHmbvbIGTjqr8=";
      };
    };

    shipwright = super.pkgs.vimUtils.buildVimPlugin {
      pname = "shipwright";
      version = "2024-03-29";
      src = super.fetchFromGitHub {
        owner = "rktjmp";
        repo = "shipwright.nvim";
        rev = "e596ab48328c31873f4f4d2e070243bf9de16ff3";
        sha256 = "sha256-xh/2m//Cno5gPucjOYih79wVZj3X1Di/U3/IQhKXjc0=";
      };
    };

    cursortab-nvim =
      let
        src = super.fetchFromGitHub {
          owner = "cursortab";
          repo = "cursortab.nvim";
          rev = "v0.7.8";
          hash = "sha256-qLFYbr/QIoM6tIV6/3CTGQrMmv4AQEzhA+ET6N1LSbs=";
        };
        server = super.pkgs.buildGoModule {
          pname = "cursortab-server";
          version = "0.7.8";
          inherit src;
          sourceRoot = "source/server";
          vendorHash = "sha256-IvJw+89eZ5Ghppjt0KT9IRL8XPyU6XbiAYL3axQO6u4=";
        };
      in
      super.pkgs.vimUtils.buildVimPlugin {
        pname = "cursortab-nvim";
        version = "0.7.8";
        inherit src;
        postInstall = ''
          mkdir -p $out/server
          cp ${server}/bin/cursortab $out/server/cursortab
        '';
      };
  });
}
