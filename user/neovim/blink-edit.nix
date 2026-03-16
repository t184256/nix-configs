{ pkgs, config, ... }:

let
  local = config.systemd.user.sockets ? llama-cpp-sweep;
  llmConfig = if local then ''
    backend = "openai",
    provider = "sweep",
    url = "http://localhost:8765",
    model = "sweep",
  '' else ''
    backend = "openai",
    provider = "sweep",
    url = "https://llm.slop.unboiled.info",
    model = "sweep",
    api_key = (function()
      local f = io.open("/mnt/secrets/llm", "r")
      local k = f and f:read("*a"):gsub("%s+$", "") or nil
      if f then f:close() end
      return k
    end)(),
  '';
in
{
  imports = [
    ../config/language-support.nix
    ../config/neovim.nix
  ];
  programs.nixvim = if (! config.neovim.fat) then {} else {
    extraPlugins = with pkgs.vimPlugins; [
      {
        plugin = blink-edit-nvim;
        optional = true;
      }
    ];
    extraConfigLua = ''
      if (vim.g.with_blink_edit == 1) then
        vim.api.nvim_command "packadd blink-edit-nvim"
        require('blink-edit').setup({
          llm = {
            ${llmConfig}
            temperature = 0.0,
            max_tokens = 256,
            stop_tokens = { "<|editable_region_end|>", "</s>", "<|endoftext|>" },
            timeout_ms = ${if local then "5000" else "30000"},
          },
          ui = {
            progress = false,
          },
          prefetch = {
            enabled = true,
          },
          context = {
            lines_before = 20,
            lines_after = 20,
            same_file = {
              enabled = true,
              max_lines_before = 40,
              max_lines_after = 40,
            },
            history = {
              enabled = true,
              max_items = 10,
              max_tokens = 1024,
              max_files = 4,
            },
            lsp = {
              enabled = true,
              max_definitions = 4,
              max_references = 4,
            },
          },
          normal_mode = {
            enabled = true,
            debounce_ms = 500,
          },
        })

        local _blink_edit_render = require("blink-edit.core.render")
        local _blink_edit_state = require("blink-edit.core.state")
        local _blink_edit_ul_ns = vim.api.nvim_create_namespace("blink-edit-underline")
        vim.api.nvim_set_hl(0, "BlinkEditSuggestion", { sp = "#9e80aa", undercurl = true })
        vim.api.nvim_set_hl(0, "BlinkEditGhost", { fg = "#9e80aa", altfont = true })
        vim.api.nvim_set_hl(0, "BlinkEditStrike", { sp = "#9e80aa", underline = true })
        vim.api.nvim_set_hl(0, "BlinkEditInsert", { sp = "#9e80aa", underdouble = true })
        _blink_edit_render.set_visibility_listeners({
          on_show = function(bufnr)
            vim.api.nvim_buf_clear_namespace(bufnr, _blink_edit_render.get_namespace(), 0, -1)
            local prediction = _blink_edit_state.get_prediction(bufnr)
            if not prediction then return end
            vim.api.nvim_buf_clear_namespace(bufnr, _blink_edit_ul_ns, 0, -1)
            local ws = prediction.window_start
            local diff = require("blink-edit.core.diff")
            local diff_result = diff.compute(prediction.snapshot_lines, prediction.predicted_lines)
            for _, hunk in ipairs(diff_result.hunks) do
              if hunk.type == "modification" then
                for _, lc in ipairs(hunk.line_changes or {}) do
                  local lnum = ws + hunk.start_old + lc.index - 3
                  local line = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1] or ""
                  if lc.change.col < #line then
                    local old_tail = line:sub(lc.change.col + 1)
                    local new_tail = lc.change.text
                    local suffix_len = 0
                    for i = 0, math.min(#old_tail, #new_tail) - 1 do
                      if old_tail:sub(#old_tail - i, #old_tail - i) == new_tail:sub(#new_tail - i, #new_tail - i) then
                        suffix_len = suffix_len + 1
                      else
                        break
                      end
                    end
                    local ul_end = #line - suffix_len
                    local ghost = new_tail:sub(1, #new_tail - suffix_len)
                    if ul_end > lc.change.col then
                      vim.api.nvim_buf_set_extmark(bufnr, _blink_edit_ul_ns, lnum, lc.change.col, {
                        hl_group = "BlinkEditStrike",
                        end_col = ul_end,
                        hl_mode = "combine",
                      })
                    elseif ghost ~= "" then
                      local curl_start = math.max(0, lc.change.col - 1)
                      local curl_end = math.min(#line, lc.change.col + 1)
                      vim.api.nvim_buf_set_extmark(bufnr, _blink_edit_ul_ns, lnum, curl_start, {
                        hl_group = "BlinkEditSuggestion",
                        end_col = curl_end,
                        hl_mode = "combine",
                      })
                    end
                    if ghost ~= "" then
                      vim.api.nvim_buf_set_extmark(bufnr, _blink_edit_ul_ns, lnum, #line, {
                        virt_text = {{ " " .. ghost, "BlinkEditGhost" }},
                        virt_text_pos = "inline",
                        priority = 1,
                      })
                    end
                  else
                    vim.api.nvim_buf_set_extmark(bufnr, _blink_edit_ul_ns, lnum, #line, {
                      virt_text = {{ lc.change.text, "BlinkEditGhost" }},
                      virt_text_pos = "inline",
                      priority = 1,
                      hl_mode = "combine",
                    })

                  end
                end
              elseif hunk.type == "insertion" then
                if hunk.start_old > 0 then
                  local before_lnum = ws + hunk.start_old - 2
                  local before_line = vim.api.nvim_buf_get_lines(bufnr, before_lnum, before_lnum + 1, false)[1] or ""
                  if #before_line > 0 then
                    vim.api.nvim_buf_set_extmark(bufnr, _blink_edit_ul_ns, before_lnum, 0, {
                      hl_group = "BlinkEditInsert",
                      end_col = 1,
                      hl_mode = "combine",
                      priority = 20,
                    })
                  end
                end
              elseif hunk.type == "deletion" or hunk.type == "replacement" then
                local first_lnum = ws + hunk.start_old - 2
                local first_buf_line = vim.api.nvim_buf_get_lines(bufnr, first_lnum, first_lnum + 1, false)[1] or ""
                local first_new = hunk.new_lines and hunk.new_lines[1] or ""
                local did_ghost = false
                if hunk.type == "replacement"
                    and vim.startswith(first_new, first_buf_line)
                    and #first_new > #first_buf_line then
                  did_ghost = true
                  vim.api.nvim_buf_set_extmark(bufnr, _blink_edit_ul_ns, first_lnum, #first_buf_line, {
                    virt_text = {{ first_new:sub(#first_buf_line + 1), "BlinkEditGhost" }},
                    virt_text_pos = "inline",
                    priority = 1,
                  })
                  local after_lnum = ws + hunk.start_old + hunk.count_old - 2
                  local after_line = vim.api.nvim_buf_get_lines(bufnr, after_lnum, after_lnum + 1, false)[1]
                  if after_line and #after_line > 0 then
                    vim.api.nvim_buf_set_extmark(bufnr, _blink_edit_ul_ns, after_lnum, 0, {
                      hl_group = "BlinkEditSuggestion",
                      end_col = 1,
                      hl_mode = "combine",
                    })
                  else
                    vim.api.nvim_buf_set_extmark(bufnr, _blink_edit_ul_ns, first_lnum, 0, {
                      virt_text = {{ " ⮐", "BlinkEditGhost" }},
                      virt_text_pos = "eol",
                    })
                  end
                end
                local start_i = did_ghost and 2 or 1
                for i = start_i, hunk.count_old do
                  local lnum = ws + hunk.start_old + i - 3
                  local line = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1] or ""
                  if #line > 0 then
                    vim.api.nvim_buf_set_extmark(bufnr, _blink_edit_ul_ns, lnum, 0, {
                      hl_group = "BlinkEditStrike",
                      end_col = #line,
                      hl_mode = "combine",
                      priority = 10,
                    })
                  end
                end
              end
            end
          end,
          on_clear = function(bufnr)
            vim.api.nvim_buf_clear_namespace(bufnr, _blink_edit_ul_ns, 0, -1)
          end,
        })


        vim.keymap.set("n", "<Tab>", function()
          local bufnr = vim.api.nvim_get_current_buf()
          local prediction = _blink_edit_state.get_prediction(bufnr)
          if not prediction then
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-i>", true, false, true), "n", false)
            return
          end
          local ws = prediction.window_start
          local diff_result = require("blink-edit.core.diff").compute(
            prediction.snapshot_lines, prediction.predicted_lines)
          local first_hunk = diff_result.hunks and diff_result.hunks[1]
          if not first_hunk then return end
          local target_line = ws + first_hunk.start_old - 1
          local target_col = 0
          if first_hunk.type == "modification"
              and first_hunk.line_changes and first_hunk.line_changes[1] then
            target_col = first_hunk.line_changes[1].change.col
          end
          local cursor = vim.api.nvim_win_get_cursor(0)
          if cursor[1] == target_line and cursor[2] == target_col then
            require("blink-edit").accept_line()
          else
            local saved_ei = vim.o.eventignore
            vim.o.eventignore = "CursorMoved,CursorMovedI,CursorHold,CursorHoldI"
            vim.api.nvim_win_set_cursor(0, { target_line, target_col })
            vim.schedule(function() vim.o.eventignore = saved_ei end)
          end
        end)

        local _blink_edit_cmp_source = {}
        _blink_edit_cmp_source.new = function()
          return setmetatable({}, { __index = _blink_edit_cmp_source })
        end
        _blink_edit_cmp_source.is_available = function()
          return require("blink-edit").has_prediction()
        end
        _blink_edit_cmp_source.get_debug_name = function() return "blink-edit" end
        _blink_edit_cmp_source.complete = function(_, params, callback)
          if not require("blink-edit").has_prediction() then
            callback({ items = {}, isIncomplete = false })
            return
          end
          local bufnr = vim.api.nvim_get_current_buf()
          local prediction = require("blink-edit.core.state").get_prediction(bufnr)
          if not prediction then
            callback({ items = {}, isIncomplete = false })
            return
          end
          local cursor_line = params.context.cursor.line  -- 0-indexed
          local kw = params.context.cursor_before_line:match("[%w_%.%-]*$") or ""
          local diff_result = require("blink-edit.core.diff").compute(
            prediction.snapshot_lines, prediction.predicted_lines)
          for _, hunk in ipairs(diff_result.hunks or {}) do
            -- start_old is 1-indexed in snapshot; 0-indexed buffer line = window_start + start_old - 2
            local hunk_line = prediction.window_start + hunk.start_old - 2
            if hunk.count_old > 0
               and cursor_line >= hunk_line
               and cursor_line < hunk_line + hunk.count_old then
              local new_lines = hunk.new_lines or {}
              local label = new_lines[1] or "(delete line)"
              local new_text, range_end
              if #new_lines == 0 then
                new_text = ""
                range_end = { line = hunk_line + hunk.count_old, character = 0 }
              else
                local last_buf_line = vim.api.nvim_buf_get_lines(
                  bufnr, hunk_line + hunk.count_old - 1, hunk_line + hunk.count_old, false)[1] or ""
                new_text = table.concat(new_lines, "\n")
                range_end = { line = hunk_line + hunk.count_old - 1, character = #last_buf_line }
              end
              callback({
                items = {{
                  label = label,
                  filterText = kw,
                  sortText = "\0",
                  textEdit = {
                    newText = new_text,
                    range = {
                      start = { line = hunk_line, character = 0 },
                      ["end"] = range_end,
                    },
                  },
                }},
                isIncomplete = false,
              })
              return
            end
          end
          callback({ items = {}, isIncomplete = false })
        end
        require("cmp").register_source("blink_edit", _blink_edit_cmp_source)

        require("null-ls").register({
          method = require("null-ls").methods.CODE_ACTION,
          filetypes = {},
          generator = {
            fn = function(params)
              local prediction = _blink_edit_state.get_prediction(params.bufnr)
              if not prediction then return end
              local ws = prediction.window_start
              return {{
                title = "blink-edit: apply suggestion",
                edit = {
                  changes = {
                    [vim.uri_from_bufnr(params.bufnr)] = {{
                      range = {
                        start = { line = ws - 1, character = 0 },
                        ["end"] = { line = ws - 1 + #prediction.snapshot_lines, character = 0 },
                      },
                      newText = table.concat(prediction.predicted_lines, "\n") .. "\n",
                    }}
                  }
                }
              }}
            end,
          },
        })
      end
    '';
  };
  home.wraplings = if (! config.neovim.fat) then {} else {
    ai = "nvim --cmd 'lua vim.g.with_blink_edit = 1'";
  };
}
