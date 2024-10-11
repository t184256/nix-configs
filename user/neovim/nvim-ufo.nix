_:

{
  programs.nixvim = {
    plugins.nvim-ufo = {
      enable = true;
      settings = {
        open_fold_hl_timeout = 0;
        close_fold_kinds.default = [];
        provider_selector = ''
          function(_, ft)
            local filetypes = {
               magit = "",
               sh = { "indent" },
            }
            return filetypes[ft] or { 'treesitter', 'indent' }
          end
        '';
      };
    };
    opts.foldlevelstart = 99;
  };
}
