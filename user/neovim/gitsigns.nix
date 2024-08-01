# see also indent-guides.nix
{ lib, config, ... }:

let
  lua = config.lib.nixvim.mkRaw;
in
{
  imports = [ ../config/neovim.nix ];
  programs.nixvim = if (! config.neovim.fat) then {} else {
    opts.signcolumn = "no";
    plugins.gitsigns = {
      enable = true;  # color changed lines
      settings = {
        attach_to_untracked = false;
        # don't show signs column and don't highlight until I press <gl>
        signcolumn = false;
        linehl = false;  # toggleable
        show_deleted = false;  # toggleable
        word_diff = false;  # toggleable
      };
    };
    keymaps = [
      {
        key = "gs";
        mode = "n";
        action = lua "package.loaded.gitsigns.stage_hunk";
      }
      {
        key = "gs";
        mode = "v";
        action = lua ''
          function()
            package.loaded.gitsigns.stage_hunk {vim.fn.line('.'), vim.fn.line('v')}
          end
        '';
      }
      {
        key = "gS";
        mode = "n";
        action = lua "package.loaded.gitsigns.undo_stage_hunk";
      }
      {
        key = "gS";
        mode = "v";
        action = ''
          function()
            package.loaded.gitsigns.undo_stage_hunk {vim.fn.line('.'), vim.fn.line('v')}
          end
        '';
      }
      {
        key = "gr";
        mode = "n";
        action = lua "package.loaded.gitsigns.reset_hunk";
      }
      {
        key = "gl";
        mode = "n";
        action = lua ''
          function()
            vim.cmd("IndentGuidesToggle")
            package.loaded.gitsigns.toggle_linehl()
            package.loaded.gitsigns.toggle_deleted()
            package.loaded.gitsigns.toggle_word_diff()
          end
        '';
      }
    ];
    # TODO: could that be done without autocmd?
    autoCmd = lib.attrsets.mapAttrsToList
      (
        hlname: color:
        {
          event = [ "VimEnter" "Colorscheme" ];
          command = ":hi ${hlname} guibg=${color}";
        }
      )
      {
        GitSignsAddLn = "#002200";
        GitSignsChangeLn = "#222200";
        GitSignsChangedeleteLn = "#220022";
        GitSignsDeleteLn = "#220000";
        GitSignsDeleteVirtLn = "#220000";
        GitSignsUntrackedLn = "#002222";
        GitSignsAddLnInline = "#003300";
        GitSignsChangeLnInline = "#333300";
        GitSignsChangedeleteLnInline = "#330033";
        GitSignsDeleteLnInline = "#330000";
        GitSignsDeleteVirtLnInline = "#330000";
        GitSignsUntrackedLnInline = "#003333";
      } ++ [
        {
          event = [ "VimEnter" "Colorscheme" ];
          command = ":hi GitSignsDeleteVirtLnInline guifg=#666666";
        }
        {
          event = [ "VimEnter" "Colorscheme" ];
          command = ":hi GitSignsDeleteVirtLn guifg=#444444";
        }
      ];
  };
}
