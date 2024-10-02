{ config, ... }:

let
  lua = config.lib.nixvim.mkRaw;
in
{
  # TODO: expand and tweak
  programs.nixvim = {
    plugins.neogit = {
      enable = true;
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
      };
    };
    keymaps = [
      {
        key = "gG";
        mode = "n";
        action = lua "function() require('neogit').open({kind='tab'}) end";
      }
    ];
  };
  home.wraplings.ng = ''
    nvim \
      '+lua require("neogit").open({kind="replace"})' \
      '+lua vim.api.nvim_buf_set_keymap(0, "n", "q", "<cmd>q<cr>", {})'
 '';
}
