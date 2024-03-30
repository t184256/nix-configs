
{ pkgs, ... }:

{
  programs.nixvim = {
    opts.colorcolumn = "80";
    highlight.ColorColumn.bg = "#202020";
    extraPlugins = with pkgs.vimPlugins; [ deadcolumn ];
    extraConfigLua = ''
      vim.cmd('highlight ColorColumn guibg=#202020');  -- see also zen-mode
      require('deadcolumn').setup ({
        scope = 'buffer',
        modes = function(mode) return true end,
        blending = {
            threshold = 0.9,
            colorcode = '#000000',
        },
        warning = {
            alpha = .5,
            offset = 1,
            colorcode = '#800000',
        },
      })
      vim.api.nvim_create_autocmd(
        {'FileType', 'BufEnter', 'BufWinEnter', 'WinEnter', 'BufLeave'}, {
        callback = function()
          if vim.bo.filetype ~= 'noice' then
            if vim.bo.filetype == 'python' then
              require('deadcolumn').configs.opts.warning.offset = 0;
            else
              require('deadcolumn').configs.opts.warning.offset = 1;
            end
          end
        end,
      })
    '';
  };
}
