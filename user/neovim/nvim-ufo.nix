_:

{
  programs.nixvim = {
    plugins.nvim-ufo = {
      enable = true;
      openFoldHlTimeout = 0;
      closeFoldKinds.default = [];
      providerSelector = ''
        function(_, ft)
          local filetypes = {
             magit = "",
             sh = { "indent" },
          }
          return filetypes[ft] or { 'treesitter', 'indent' }
        end
      '';
    };
    opts.foldlevelstart = 99;
  };
}
