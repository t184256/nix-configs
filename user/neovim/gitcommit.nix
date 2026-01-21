{ config, ... }:

let
  lua = config.lib.nixvim.mkRaw;
in
{
  programs.nixvim.autoCmd = [
    {
      event = "FileType";
      pattern = [ "gitcommit" ];
      callback = lua ''
        function()
          vim.opt_local.undofile = false
          vim.b.undofile_warn_saved = vim.fn.changenr()
        end
      '';
    }
  ];
}
