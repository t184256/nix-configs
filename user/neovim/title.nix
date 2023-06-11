{ config, pkgs, lib, inputs, ... }:

{
  programs.nixvim = {
    options = {
      title = true;
      titlestring = ("vi > %y %t%H%R > %P/%LL " +
                     "%-13.(%l:%c%V %{v:lua.NiceMode()}%)");
      titlelen = 200;
    };
    extraConfigLua = ''
      do
        local NiceModeTable = {
          n = ''', i = '[INS]', R = '[RPL]', c = '[CMD]', t = '[TRM]',
          v = '[VIS]', V = '[VIL]', ['<C-v>'] = '[VIB]',
          s = '[SEL]', S = '[S-L]', ['<C-s>'] = '[S-B]',
        }
        function _G.NiceMode()
          local mode = vim.api.nvim_get_mode().mode
          return NiceModeTable[mode] or mode
        end
      end
    '';
  };
}
