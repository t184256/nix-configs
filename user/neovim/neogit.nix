{ pkgs, config, ... }:

let
  lua = config.lib.nixvim.mkRaw;
in
{
  # TODO: expand and tweak
  programs.nixvim = {
    plugins.neogit = {
      enable = true;
      package = pkgs.vimPlugins.neogit;  # overlayed in overlays/vim-plugins.nix
      settings = {
        graph_style = "unicode";
        commit_select_view.kind = "replace";
        sections.unstaged = {
          folded = false;
          hidden = false;
        };
        mappings = {
          commit_editor = {
            q = "Close";
            "<c-c><c-c>" = "Submit";
            "<c-c><c-k>" = "Abort";
            "<Space>p" = "PrevMessage";
            "<Space>n" = "NextMessage";
            "<Space>r" = "ResetMessage";
          };
          finder = {
            "<Space>n" = "Next";
            "<Space>p" = "Previous";
          };
        };
        process_spinner = false;
      };
    };
    keymaps = [
      {
        key = "gG";
        mode = "n";
        action = lua "function() require('neogit').open({kind='tab'}) end";
      }
    ];
    autoCmd = [
      {
        event = "FileType";
        pattern = "gitcommit";
        callback = lua ''
          function()
            vim.opt_local.wrap = true
            vim.opt_local.linebreak = true
            vim.opt_local.undofile = false
          end
        '';
      }
    ];
  };
  home.wraplings.ng = ''
    nvim \
      '+lua require("neogit").open({kind="replace"})' \
      '+lua vim.api.nvim_buf_set_keymap(0, "n", "q", "<cmd>q<cr>", {})'
 '';
}
