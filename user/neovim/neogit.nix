{ pkgs, ... }:

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
            #a = ''
            #  function()
            #    vim.fn.system("git absorb");
            #    require('neogit').refresh());
            #  end
            #'';
          };
          finder = {
            "<Space>n" = "Next";
            "<Space>p" = "Previous";
          };
        };
      };
    };
  };
  home.wraplings.ng =
    "nvim '+lua require(\"neogit\").open({kind=\"replace\"})'";
}
