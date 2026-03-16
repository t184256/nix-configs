vim.api.nvim_set_hl(0, "BlinkEditSuggestion",  { sp = "#9e80aa", undercurl = true })
vim.api.nvim_set_hl(0, "BlinkEditGhost",       { fg = "#9e80aa", altfont = true })
vim.api.nvim_set_hl(0, "BlinkEditStrike",      { sp = "#9e80aa", underline = true })
vim.api.nvim_set_hl(0, "BlinkEditInsertLines", { sp = "#9e80aa", underdouble = true })

local render = require("blink-edit.core.render")
local state = require("blink-edit.core.state")
local ul_ns = vim.api.nvim_create_namespace("blink-edit-underline")

local function hunk_target(bufnr, ws, hunk)
  local tl = ws + hunk.start_old - 1
  local bl = vim.api.nvim_buf_get_lines(bufnr, tl - 1, tl, false)[1] or ""
  local last = math.max(0, #bl - 1)
  local tc
  if hunk.type == "modification" then
    local lc = hunk.line_changes and hunk.line_changes[1]
    tc = lc and math.min(lc.change.col, last) or last
  elseif hunk.type == "replacement" then
    local fn = hunk.new_lines and hunk.new_lines[1] or ""
    tc = (vim.startswith(fn, bl) and #fn > #bl) and last or 0
  elseif hunk.type == "insertion" then
    tc = last
  else
    tc = 0
  end
  return tl, tc
end

local function apply_hunk(bufnr, ws, h)
  local base = ws + h.start_old - 2
  if h.type == "insertion" then
    vim.api.nvim_buf_set_lines(bufnr, base + 1, base + 1, false, h.new_lines or {})
  elseif h.type == "deletion" then
    vim.api.nvim_buf_set_lines(bufnr, base, base + h.count_old, false, {})
  elseif h.type == "replacement" then
    vim.api.nvim_buf_set_lines(bufnr, base, base + h.count_old, false, h.new_lines or {})
  elseif h.type == "modification" then
    local new_lines = {}
    for i = 1, h.count_old do
      local lnum = base + i - 1
      local old_line = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1] or ""
      local new_line = old_line
      for _, lc in ipairs(h.line_changes or {}) do
        if lc.index == i then
          new_line = old_line:sub(1, lc.change.col) .. lc.change.text
          break
        end
      end
      table.insert(new_lines, new_line)
    end
    vim.api.nvim_buf_set_lines(bufnr, base, base + h.count_old, false, new_lines)
  end
end

render.set_visibility_listeners({
  on_show = function(bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, render.get_namespace(), 0, -1)
    local prediction = state.get_prediction(bufnr)
    if not prediction then return end
    vim.api.nvim_buf_clear_namespace(bufnr, ul_ns, 0, -1)
    local ws = prediction.window_start
    local diff_result = require("blink-edit.core.diff").compute(
      prediction.snapshot_lines, prediction.predicted_lines)
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
              vim.api.nvim_buf_set_extmark(bufnr, ul_ns, lnum, lc.change.col, {
                hl_group = "BlinkEditStrike",
                end_col = ul_end,
                hl_mode = "combine",
              })
            elseif ghost ~= "" then
              local curl_start = math.max(0, lc.change.col - 1)
              local curl_end = math.min(#line, lc.change.col + 1)
              vim.api.nvim_buf_set_extmark(bufnr, ul_ns, lnum, curl_start, {
                hl_group = "BlinkEditSuggestion",
                end_col = curl_end,
                hl_mode = "combine",
              })
            end
            if ghost ~= "" then
              vim.api.nvim_buf_set_extmark(bufnr, ul_ns, lnum, #line, {
                virt_text = {{ " " .. ghost, "BlinkEditGhost" }},
                virt_text_pos = "inline",
                priority = 1,
              })
            end
          else
            vim.api.nvim_buf_set_extmark(bufnr, ul_ns, lnum, #line, {
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
            vim.api.nvim_buf_set_extmark(bufnr, ul_ns, before_lnum, 0, {
              hl_group = "BlinkEditInsertLines",
              end_col = 1,
              hl_mode = "combine",
              priority = 20,
            })
          end
          local first_new = hunk.new_lines and hunk.new_lines[1] or ""
          if first_new ~= "" then
            vim.api.nvim_buf_set_extmark(bufnr, ul_ns, before_lnum, #before_line, {
              virt_text = {{ "⮐" .. first_new:gsub("^%s*", " "), "BlinkEditGhost" }},
              virt_text_pos = "inline",
              priority = 1,
            })
          end
        end
      elseif hunk.type == "deletion" or hunk.type == "replacement" then
        local first_lnum = ws + hunk.start_old - 2
        local first_buf_line = vim.api.nvim_buf_get_lines(bufnr, first_lnum, first_lnum + 1, false)[1] or ""
        local first_new = hunk.new_lines and hunk.new_lines[1] or ""
        local did_ghost = false
        local first_word = function(s) return s:match("^%s*([^%s]+)") or "" end
        if hunk.type == "replacement"
            and first_new ~= ""
            and not vim.startswith(first_new, first_buf_line)
            and first_word(first_new) ~= first_word(first_buf_line)
            and first_lnum > 0 then
          local prev_line = vim.api.nvim_buf_get_lines(bufnr, first_lnum - 1, first_lnum, false)[1] or ""
          vim.api.nvim_buf_set_extmark(bufnr, ul_ns, first_lnum - 1, #prev_line, {
            virt_text = {{ "⮐" .. first_new:gsub("^%s*", " "), "BlinkEditGhost" }},
            virt_text_pos = "inline",
            priority = 1,
          })
        end
        if hunk.type == "replacement"
            and vim.startswith(first_new, first_buf_line)
            and #first_new > #first_buf_line then
          did_ghost = true
          vim.api.nvim_buf_set_extmark(bufnr, ul_ns, first_lnum, #first_buf_line, {
            virt_text = {{ first_new:sub(#first_buf_line + 1), "BlinkEditGhost" }},
            virt_text_pos = "inline",
            priority = 1,
          })
          local after_lnum = ws + hunk.start_old + hunk.count_old - 2
          local after_line = vim.api.nvim_buf_get_lines(bufnr, after_lnum, after_lnum + 1, false)[1]
          if after_line and #after_line > 0 then
            vim.api.nvim_buf_set_extmark(bufnr, ul_ns, after_lnum, 0, {
              hl_group = "BlinkEditSuggestion",
              end_col = 1,
              hl_mode = "combine",
            })
          else
            vim.api.nvim_buf_set_extmark(bufnr, ul_ns, first_lnum, 0, {
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
            vim.api.nvim_buf_set_extmark(bufnr, ul_ns, lnum, 0, {
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
    vim.api.nvim_buf_clear_namespace(bufnr, ul_ns, 0, -1)
  end,
})

vim.keymap.set("n", "<Tab>", function()
  local bufnr = vim.api.nvim_get_current_buf()
  local prediction = state.get_prediction(bufnr)
  if not prediction then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-i>", true, false, true), "n", false)
    return
  end
  local ws = prediction.window_start
  local diff_result = require("blink-edit.core.diff").compute(
    prediction.snapshot_lines, prediction.predicted_lines)
  if not diff_result.hunks or #diff_result.hunks == 0 then return end

  local cursor = vim.api.nvim_win_get_cursor(0)
  -- accept if cursor is already at any hunk's target
  for _, hunk in ipairs(diff_result.hunks) do
    local tl, tc = hunk_target(bufnr, ws, hunk)
    if cursor[1] == tl and cursor[2] == tc then
      apply_hunk(bufnr, ws, hunk)
      return
    end
  end
  -- find first hunk target strictly after cursor
  local jump_line, jump_col
  for _, hunk in ipairs(diff_result.hunks) do
    local tl, tc = hunk_target(bufnr, ws, hunk)
    local after = tl > cursor[1] or (tl == cursor[1] and tc > cursor[2])
    if after and (not jump_line or tl < jump_line or (tl == jump_line and tc < jump_col)) then
      jump_line, jump_col = tl, tc
    end
  end
  -- wrap to first hunk if all are before cursor
  if not jump_line then
    jump_line, jump_col = hunk_target(bufnr, ws, diff_result.hunks[1])
  end
  vim.cmd("normal! m'")
  local saved_ei = vim.o.eventignore
  vim.o.eventignore = "CursorMoved,CursorMovedI,CursorHold,CursorHoldI"
  vim.api.nvim_win_set_cursor(0, { jump_line, jump_col })
  vim.schedule(function() vim.o.eventignore = saved_ei end)
end)

local cmp_source = {}
cmp_source.new = function()
  return setmetatable({}, { __index = cmp_source })
end
cmp_source.is_available = function()
  return require("blink-edit").has_prediction()
end
cmp_source.get_debug_name = function() return "blink-edit" end
cmp_source.complete = function(_, params, callback)
  if not require("blink-edit").has_prediction() then
    callback({ items = {}, isIncomplete = false })
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local prediction = state.get_prediction(bufnr)
  if not prediction then
    callback({ items = {}, isIncomplete = false })
    return
  end
  local cursor_line = params.context.cursor.line  -- 0-indexed
  local kw = params.context.cursor_before_line:match("[%w_%.%-]*$") or ""
  local diff_result = require("blink-edit.core.diff").compute(
    prediction.snapshot_lines, prediction.predicted_lines)
  for _, hunk in ipairs(diff_result.hunks or {}) do
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
require("cmp").register_source("blink_edit", cmp_source)

require("null-ls").register({
  method = require("null-ls").methods.CODE_ACTION,
  filetypes = {},
  generator = {
    fn = function(params)
      local prediction = state.get_prediction(params.bufnr)
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
