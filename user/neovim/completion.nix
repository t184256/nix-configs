{ pkgs, config, ... }:

{
  imports = [ ../config/neovim.nix ];
  programs.nixvim = if (! config.neovim.fat) then {} else {
    plugins = {
      cmp-path.enable = true;
      cmp-treesitter.enable = true;
      luasnip.enable = true;
      cmp_luasnip.enable = true;
      cmp = {
        enable = true;
        settings = {
          completion.autocomplete = false;
          sources = [
            { groupIndex = 0; name = "blink_edit"; }
            { groupIndex = 1; name = "path"; }
            { groupIndex = 1; name = "nvim_lsp"; }
            { groupIndex = 2; name = "luasnip"; }
            { groupIndex = 2; name = "buffer"; }
          ];
          snippet.expand =
            "function(args) require('luasnip').lsp_expand(args.body) end";
          formatting.format =
            "function(entry, vim_item) if entry.source.name == \"blink_edit\" then vim_item.kind = \"AI\" end return vim_item end";
          mapping = {
            "<C-c>" = "cmp.mapping.abort()";
            "<CR>" = "cmp.mapping(function(fallback) if cmp.visible() and cmp.get_selected_entry() then cmp.confirm({ select = false }) else fallback() end end)";
            "<Tab>" = ''
              function(fallback)
                local cmp = require('cmp')
                local luasnip = require('luasnip')
                local blink_edit = package.loaded["blink-edit"] and require("blink-edit")
                local now = vim.uv.now()
                local double_tap = (now - _blink_edit_last_tab_ms) < 300
                _blink_edit_last_tab_ms = now
                if blink_edit and blink_edit.has_prediction() and not cmp.visible() and double_tap then
                  blink_edit.accept_line()
                elseif cmp.visible() then
                  cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
                elseif blink_edit and blink_edit.has_prediction() then
                  cmp.complete()
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
                  cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
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

    keymaps = [{
      mode = "i";
      key = "<Right>";
      action.__raw = ''
        function()
          local be = package.loaded["blink-edit"] and require("blink-edit")
          local at_end = vim.fn.col(".") > #vim.api.nvim_get_current_line()
          if be and be.has_prediction() and at_end then
            vim.schedule(function() be.accept_line() end)
            return ""
          end
          return "<Right>"
        end
      '';
      options = {
        expr = true;
        noremap = true;
        desc = "Accept blink-edit or move right";
      };
    }];
    extraPlugins = with pkgs.vimPlugins; [ friendly-snippets ];
    opts.completeopt = [ "menu" "menuone" "noselect" ];
    extraConfigLua = ''
      require('luasnip.loaders.from_vscode').lazy_load()

      function check_backspace()
        local col = vim.fn.col(".") - 1
        return col == 0 or vim.fn.getline("."):sub(col, col):match("%s")
      end

      _blink_edit_last_tab_ms = 0
    '';
  };
}
