{ pkgs, config, ... }:

{
  imports = [
    ../config/language-support.nix
    ../config/neovim.nix
  ];
  programs.nixvim = if (! config.neovim.fat) then {} else {
    # fancy plugins: treesitter
    plugins.treesitter = {
      # playground  # :TSHighlightCapturesUnderCursor,
                    # :help treesitter-highlight-groups
      enable = config.language-support != [];
      # TODO: use all for fat vim, limited for slim vim?
      grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
        #ini
        awk
        bash
        c
        cmake
        comment
        css
        csv
        dhall
        diff
        disassembly
        editorconfig
        git_config
        git_rebase
        gitattributes
        gitcommit
        gitignore
        gpg
        html
        http
        java
        javascript
        jq
        json
        json5
        kconfig
        kotlin
        latex
        ledger
        lua
        make
        markdown
        nginx
        ninja
        nix
        org
        passwd
        pem
        printf
        properties
        python
        regex
        requirements
        robots
        rst
        ruby
        rust
        sql
        ssh_config
        strace
        tmux
        todotxt
        toml
        typst
        udev
        vimdoc
        xml
        yaml
      ];
      settings.highlight = {
        enable = true;
        indent = true;
        #additional_vim_regex_highlighting = false;
      };
      #vim.api.nvim_set_hl(0, "@none", { link = "Normal" })
    };
    plugins.treesitter-context = {
      enable = true;
      settings = {
        mode = "topline";
        min_window_height = 36;
        max_lines = 2;
      };
    };
    extraConfigLua = ''
      vim.cmd('highlight TreesitterContext gui=reverse');
    '';
  };
}
