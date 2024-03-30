{ pkgs, config, ... }:

{
  imports = [ ../config/neovim.nix ];
  programs.nixvim = if (! config.neovim.fat) then {} else {
    plugins = {
      cmp-path.enable = true;
      cmp-tmux.enable = true;
      cmp-treesitter.enable = true;
      luasnip.enable = true;
      cmp_luasnip.enable = true;
      cmp = {
        enable = true;
        settings = {
          completion.autocomplete = false;
          sources = [
            { groupIndex = 1; name = "path"; }
            { groupIndex = 1; name = "nvim_lsp"; }
            { groupIndex = 2; name = "luasnip"; }
            { groupIndex = 2; name = "buffer"; }
            { groupIndex = 3; name = "tmux"; }
          ];
          snippet.expand =
            "function(args) require('luasnip').lsp_expand(args.body) end";
          mapping = {
            "<C-c>" = "cmp.mapping.abort()";
            "<Tab>" = ''
              function(fallback)
                local cmp = require('cmp')
                local luasnip = require('luasnip')
                if cmp.visible() then
                  if not cmp.complete_common_string() then
                    cmp.select_next_item(select_opts)
                  end
                elseif check_backspace() then
                  fallback()
                elseif luasnip.expandable() then
                  luasnip.expand()
                elseif luasnip.expand_or_locally_jumpable() then
                  luasnip.expand_or_jump()
                else
                  cmp.complete()
                end
              end
            '';
            "<S-Tab>" = ''
              function(fallback)
                local cmp = require('cmp')
                local luasnip = require('luasnip')
                if cmp.visible() then
                  cmp.select_prev_item(select_opts)
                elseif luasnip.locally_jumpable(-1) then
                  luasnip.jump(-1)
                else
                  fallback()
                end
              end
            '';
          };
        };
      };
    };

    extraPlugins = with pkgs.vimPlugins; [ friendly-snippets ];
    opts.completeopt = [ "menu" "menuone" "noselect" ];
    extraConfigLua = ''
      require('luasnip.loaders.from_vscode').lazy_load()

      function check_backspace()
        local col = vim.fn.col(".") - 1
        return col == 0 or vim.fn.getline("."):sub(col, col):match("%s")
      end
    '';
  };
}
