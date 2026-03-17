-- blink-edit-ui.lua — Suggestion-based UI for blink-edit.nvim
--
-- blink-edit produces raw diff hunks (insertion/deletion/
-- modification/replacement). This module decomposes each hunk
-- into a cursor target + ordered atomic changes ("Suggestion").
-- Suggestions drive rendering (extmarks), Tab/Right acceptance,
-- and cmp/null-ls integration uniformly.
--
-- Flow:
--   engine prediction
--     → on_show → compute_suggestions (diff → decompose)
--     → cache → render extmarks
--   Tab press → read cache → jump to target or apply change

-- ===========================================================
-- Highlight groups
-- ===========================================================
-- BlinkEditSuggestion : undercurl near modification point
-- BlinkEditGhost      : inline virtual text (insert/change)
-- BlinkEditStrike     : underline on replaced/deleted chars
-- BlinkEditInsertLines: underdouble on char before insertions

local hl = vim.api.nvim_set_hl
hl(0, "BlinkEditSuggestion",  { sp = "#9e80aa", undercurl = true })
hl(0, "BlinkEditGhost",       { fg = "#9e80aa", altfont = true })
hl(0, "BlinkEditStrike",      { sp = "#9e80aa", underline = true })
hl(0, "BlinkEditInsertLines", { sp = "#9e80aa", underdouble = true })

local render = require("blink-edit.core.render")
local state = require("blink-edit.core.state")
local diff = require("blink-edit.core.diff")
local api = vim.api

-- Separate namespace for our UI extmarks (strike, ghost,
-- undercurl). blink-edit's render module uses its own ns;
-- we layer on top and clear independently.
local ul_ns = api.nvim_create_namespace("blink-edit-underline")

-- ===========================================================
-- String helpers
-- ===========================================================

-- Shared prefix and suffix lengths between two strings,
-- with suffix clamped so it doesn't overlap the prefix.
-- Returns plen, slen (both in bytes).
local function diff_bounds(a, b)
  local n = math.min(#a, #b)
  local plen = 0
  for i = 1, n do
    if a:sub(i, i) ~= b:sub(i, i) then break end
    plen = i
  end
  local slen = 0
  for i = 0, n - plen - 1 do
    if a:sub(#a - i, #a - i)
       ~= b:sub(#b - i, #b - i) then
      break
    end
    slen = i + 1
  end
  return plen, slen
end

-- Replace leading whitespace with visible characters so
-- ghost text doesn't start with invisible gaps.
--   spaces → ·   tabs → →   (with padding)
local function visible_leading_ws(s)
  local ws, rest = s:match("^(%s+)(.*)")
  if not ws then return s end
  return ws:gsub(" ", "·"):gsub("\t", "→   ") .. rest
end

-- Read a single buffer line (0-indexed). Returns "".
local function buf_line(bufnr, lnum)
  return (api.nvim_buf_get_lines(
    bufnr, lnum, lnum + 1, false
  )[1] or "")
end

-- ===========================================================
-- Data structures
-- ===========================================================

-- AtomicChange: smallest unit of a suggestion — one
-- line-level operation that can be applied independently.
--
---@class AtomicChange
---@field kind "modification"|"insertion"|"deletion"
---@field lnum number      -- 0-indexed buffer line
---@field old_text string? -- original (modification/deletion)
---@field new_text string? -- replacement (modification/insertion)
---@field strike_start number? -- 0-indexed col (modification)
---@field strike_end number?   -- 0-indexed col (modification)
---@field ghost string?        -- inline ghost preview text

-- Suggestion: groups related changes with a cursor target
-- for Tab navigation. Changes ordered: modifications first,
-- then insertions, then deletions — most informative first.
--
---@class Suggestion
---@field target_line number -- 1-indexed (cursor jump)
---@field target_col number  -- 0-indexed (cursor jump)
---@field changes AtomicChange[]

-- ===========================================================
-- Hunk → Suggestion decomposition
-- ===========================================================
-- Each DiffHunk becomes one or more Suggestions.
-- Strategy depends on hunk type.

-- Modification hunks: equal old/new line counts (1:1).
-- Split at unchanged-line gaps so Tab cycles each change.
--
-- Example: 5-line mod, lines 1,4 changed, 2,3,5 same
--   → two Suggestions (line 1 and line 4).
local function decompose_modification_hunk(ws, hunk)
  -- Walk lines in lockstep; consecutive changed lines
  -- form a group; unchanged lines break groups.
  local groups = {}
  local cur = {}
  for i = 1, hunk.count_old do
    if hunk.old_lines[i] == hunk.new_lines[i] then
      -- Unchanged — flush current group
      if #cur > 0 then
        table.insert(groups, cur)
        cur = {}
      end
    else
      table.insert(cur, {
        index = i,
        old = hunk.old_lines[i],
        new = hunk.new_lines[i],
      })
    end
  end
  if #cur > 0 then table.insert(groups, cur) end

  -- Each group → one Suggestion with modification changes.
  local suggestions = {}
  for _, group in ipairs(groups) do
    local changes = {}
    local first_entry = group[1]
    -- Hunk-relative index → 0-indexed buffer line:
    --   ws(1-idx) + start_old(1-idx) + index(1-idx) - 3
    local lnum0 =
      ws + hunk.start_old + first_entry.index - 3
    local target_col = 0

    for _, entry in ipairs(group) do
      -- 0-indexed buffer line for this entry
      local el = ws + hunk.start_old + entry.index - 3

      -- Find changed portion: trim shared prefix/suffix
      local plen, slen = diff_bounds(entry.old, entry.new)

      local s_start = plen
      local s_end = #entry.old - slen
      local ghost =
        entry.new:sub(plen + 1, #entry.new - slen)

      if s_end > s_start or ghost ~= "" then
        if entry == first_entry then
          target_col = s_start > 0 and s_start or 0
        end
        table.insert(changes, {
          kind = "modification",
          lnum = el,
          old_text = entry.old,
          new_text = entry.new,
          strike_start = s_start,
          strike_end = s_end,
          ghost = ghost,
        })
      end
    end

    if #changes > 0 then
      table.insert(suggestions, {
        target_line = lnum0 + 1, -- 1-indexed
        target_col = target_col,
        changes = changes,
      })
    end
  end
  return suggestions
end

-- Insertion hunks: new lines added, nothing deleted.
-- All new lines become insertion changes anchored after
-- the preceding line. Tab target = end of anchor line
-- (where ⮐ is displayed).
local function decompose_insertion_hunk(ws, hunk)
  -- anchor_lnum: 0-indexed buffer line *before* insertion.
  -- start_old is 1-indexed in snapshot.
  local anchor = ws + hunk.start_old - 2

  local changes = {}
  for i, line in ipairs(hunk.new_lines or {}) do
    table.insert(changes, {
      kind = "insertion",
      -- Each insertion goes one line further down.
      -- Applied one-at-a-time; re-prediction handles
      -- the shift via TextChanged.
      lnum = anchor + i - 1,
      new_text = line,
      ghost = line,
    })
  end

  -- Read anchor line to place cursor at its end
  local bl = anchor >= 0 and buf_line(0, anchor) or ""

  return {{
    target_line = math.max(1, anchor + 1), -- 1-indexed
    target_col = math.max(0, #bl - 1),     -- last char
    changes = changes,
  }}
end

-- Deletion hunks: old lines removed, nothing added.
-- Each old line → a deletion change.
-- Tab target = first deleted line.
local function decompose_deletion_hunk(ws, hunk)
  local changes = {}
  for i = 1, hunk.count_old do
    local lnum = ws + hunk.start_old + i - 3
    table.insert(changes, {
      kind = "deletion",
      lnum = lnum,
      old_text = hunk.old_lines[i],
    })
  end
  return {{
    target_line = ws + hunk.start_old - 1,
    target_col = 0,
    changes = changes,
  }}
end

-- Replacement hunks: different old/new line counts.
-- First-line analysis decides presentation:
--
--   1. Extension (new starts with old):
--      → modification with ghost at EOL, no strike
--
--   2. Shared first word (same fn name, different args):
--      → modification with strike + ghost
--
--   3. Neither (completely different):
--      → insertion (⮐ on preceding line)
--
-- Remaining new lines → insertions.
-- Remaining old lines → deletions.
-- Sorted: modifications > insertions > deletions.
local function decompose_replacement_hunk(bufnr, ws, hunk)
  -- base_lnum: 0-indexed line of first old line
  local base = ws + hunk.start_old - 2
  local old1 = hunk.old_lines and hunk.old_lines[1] or ""
  local new1 = hunk.new_lines and hunk.new_lines[1] or ""
  local changes = {}
  local tgt_line = base + 1 -- 1-indexed default
  local tgt_col = 0

  -- Track whether first old/new consumed by first-line
  -- analysis (avoid double-counting in remaining loops).
  local ate_old = false
  local ate_new = false

  if vim.startswith(new1, old1) and #new1 > #old1 then
    -- Case 1: Extension — old + more text at end.
    -- Ghost at EOL, no strikethrough.
    table.insert(changes, {
      kind = "modification",
      lnum = base,
      old_text = old1,
      new_text = new1,
      strike_start = #old1, -- empty range
      strike_end = #old1,
      ghost = new1:sub(#old1 + 1),
    })
    tgt_col = math.max(0, #old1 - 1)
    ate_old, ate_new = true, true

  else
    -- Case 2: check for shared prefix.
    -- If prefix > 0, show as modification with strike
    -- on diverging portion. Otherwise, first new line
    -- becomes an insertion (⮐) on the preceding line.
    local plen, slen = diff_bounds(old1, new1)
    if plen > 0 then
      table.insert(changes, {
        kind = "modification",
        lnum = base,
        old_text = old1,
        new_text = new1,
        strike_start = plen,
        strike_end = #old1 - slen,
        ghost = new1:sub(plen + 1, #new1 - slen),
      })
      tgt_col = plen
      ate_old, ate_new = true, true
    else
      -- No shared prefix — insertion on prev line.
      local arrow = math.max(0, base - 1)
      if new1 ~= "" then
        table.insert(changes, {
          kind = "insertion",
          lnum = arrow,
          new_text = new1,
          ghost = new1,
        })
        ate_new = true
      end
      -- Target at end of ⮐ line
      local al = buf_line(bufnr, arrow)
      tgt_line = arrow + 1
      tgt_col = math.max(0, #al - 1)
    end
  end

  -- Remaining new lines → insertions.
  -- Anchor depends on whether first old was consumed
  -- (insert after it) or not (after line before block).
  local ins_anchor = ate_old and base
    or math.max(0, base - 1)
  local nstart = ate_new and 2 or 1
  for i = nstart, #(hunk.new_lines or {}) do
    table.insert(changes, {
      kind = "insertion",
      lnum = ins_anchor + (i - nstart),
      new_text = hunk.new_lines[i],
      ghost = hunk.new_lines[i],
    })
  end

  -- Remaining old lines → deletions.
  local ostart = ate_old and 2 or 1
  for i = ostart, hunk.count_old do
    table.insert(changes, {
      kind = "deletion",
      lnum = base + i - 1,
      old_text = hunk.old_lines[i],
    })
  end

  -- Sort: most useful change applied first.
  -- modification > insertion > deletion
  table.sort(changes, function(a, b)
    local ord = {
      modification = 1,
      insertion = 2,
      deletion = 3,
    }
    return (ord[a.kind] or 9) < (ord[b.kind] or 9)
  end)

  return {{
    target_line = tgt_line,
    target_col = tgt_col,
    changes = changes,
  }}
end

-- Top-level: diff prediction vs snapshot, decompose each
-- hunk into Suggestions. Returns flat list by buffer position.
local function compute_suggestions(bufnr)
  local prediction = state.get_prediction(bufnr)
  if not prediction then return {} end

  -- ws: 1-indexed start of context window
  local ws = prediction.window_start
  local dr = diff.compute(
    prediction.snapshot_lines,
    prediction.predicted_lines
  )
  if not dr.has_changes then return {} end

  local suggestions = {}
  for _, hunk in ipairs(dr.hunks) do
    local subs
    if hunk.type == "modification" then
      subs = decompose_modification_hunk(ws, hunk)
    elseif hunk.type == "insertion" then
      subs = decompose_insertion_hunk(ws, hunk)
    elseif hunk.type == "deletion" then
      subs = decompose_deletion_hunk(ws, hunk)
    elseif hunk.type == "replacement" then
      subs = decompose_replacement_hunk(bufnr, ws, hunk)
    end
    if subs then
      for _, s in ipairs(subs) do
        table.insert(suggestions, s)
      end
    end
  end
  return suggestions
end

-- ===========================================================
-- Suggestion cache
-- ===========================================================
-- Keyed by bufnr. Populated by on_show (new prediction).
-- NOT cleared by on_clear — lets Tab cycle stale suggestions
-- while a new prediction is in flight. Replaced atomically
-- by on_show, or cleared when all changes consumed.

---@type table<number, Suggestion[]>
local suggestions_cache = {}

-- ===========================================================
-- Rendering
-- ===========================================================
-- Each AtomicChange renders via extmarks in ul_ns.

-- Modification change:
-- - Strike range → BlinkEditStrike underline
-- - No strike but ghost → BlinkEditSuggestion undercurl hint
-- - Ghost text → inline virtual text at EOL
local function render_modification(bufnr, change)
  local line = buf_line(bufnr, change.lnum)
  local ss = change.strike_start
  local se = change.strike_end

  if se > ss and se <= #line then
    -- Strikethrough replaced portion
    api.nvim_buf_set_extmark(bufnr, ul_ns, change.lnum, ss, {
      hl_group = "BlinkEditStrike",
      end_col = se,
      hl_mode = "combine",
    })
  elseif (change.ghost or "") ~= "" then
    -- No strike range (e.g. pure append) — small
    -- undercurl hint near the change point
    local cs = math.max(0, ss - 1)
    local ce = math.min(#line, ss + 1)
    if ce > cs then
      api.nvim_buf_set_extmark(
        bufnr, ul_ns, change.lnum, cs, {
          hl_group = "BlinkEditSuggestion",
          end_col = ce,
          hl_mode = "combine",
        }
      )
    end
  end

  -- Ghost text inline at EOL.
  -- Appends (no strike range) flow directly from the
  -- existing text; modifications get a separating space.
  if (change.ghost or "") ~= "" then
    local is_append = se <= ss
    local text = is_append
      and change.ghost
      or (" " .. visible_leading_ws(change.ghost))
    api.nvim_buf_set_extmark(
      bufnr, ul_ns, change.lnum, #line, {
        virt_text = {{ text, "BlinkEditGhost" }},
        virt_text_pos = "inline",
        priority = 1,
      }
    )
  end
end

-- Render insertion changes as a group.
-- First insertion text shown as ⮐ ghost on anchor line.
-- Additional insertions get "(+N more)" suffix.
-- Anchor line gets underdouble on first char.
--
-- If a modification already occupies the anchor line
-- (same suggestion), the ⮐ ghost is condensed to just a
-- count — avoids two ghost texts stacking at EOL.
local function render_insertions(bufnr, sug)
  local ins = {}
  for _, c in ipairs(sug.changes) do
    if c.kind == "insertion" then
      table.insert(ins, c)
    end
  end
  if #ins == 0 then return end

  local anchor = ins[1].lnum -- 0-indexed ⮐ line
  if anchor < 0 then return end

  local al = buf_line(bufnr, anchor)

  -- Underdouble hint on first char
  if #al > 0 then
    api.nvim_buf_set_extmark(bufnr, ul_ns, anchor, 0, {
      hl_group = "BlinkEditInsertLines",
      end_col = 1,
      hl_mode = "combine",
      priority = 20,
    })
  end

  -- Check if a modification ghost is already on anchor
  local mod_on_anchor = false
  for _, c in ipairs(sug.changes) do
    if c.kind == "modification" and c.lnum == anchor then
      mod_on_anchor = true
      break
    end
  end

  if mod_on_anchor then
    -- Compact count — anchor already has a mod ghost
    local label = #ins == 1
      and "⮐"
      or string.format("⮐(+%d)", #ins)
    api.nvim_buf_set_extmark(bufnr, ul_ns, anchor, #al, {
      virt_text = {{ " " .. label, "BlinkEditGhost" }},
      virt_text_pos = "eol",
      priority = 1,
    })
  else
    -- Full ghost: ⮐ + first line text + count suffix
    local ghost = ins[1].ghost or ""
    local suffix = #ins > 1
      and string.format(" (+%d more)", #ins - 1)
      or ""
    if ghost ~= "" or suffix ~= "" then
      api.nvim_buf_set_extmark(
        bufnr, ul_ns, anchor, #al, {
          virt_text = {{
            "⮐ " .. visible_leading_ws(ghost) .. suffix,
            "BlinkEditGhost",
          }},
          virt_text_pos = "inline",
          priority = 1,
        }
      )
    end
  end
end

-- Deletion change: full-line strikethrough.
local function render_deletion(bufnr, change)
  local line = buf_line(bufnr, change.lnum)
  if #line > 0 then
    api.nvim_buf_set_extmark(
      bufnr, ul_ns, change.lnum, 0, {
        hl_group = "BlinkEditStrike",
        end_col = #line,
        hl_mode = "combine",
        priority = 10,
      }
    )
  end
end

-- Render all changes in a suggestion.
-- Modifications/deletions per-change; insertions grouped.
local function render_suggestion(bufnr, sug)
  local has_ins = false
  for _, change in ipairs(sug.changes) do
    if change.kind == "modification" then
      render_modification(bufnr, change)
    elseif change.kind == "insertion" then
      has_ins = true -- rendered as group below
    elseif change.kind == "deletion" then
      render_deletion(bufnr, change)
    end
  end
  if has_ins then
    render_insertions(bufnr, sug)
  end
end

-- ===========================================================
-- Apply logic
-- ===========================================================
-- Applies exactly one change (first in sug.changes), removes
-- it. The buffer edit triggers TextChanged → re-prediction.

-- Clear all suggestion extmarks and re-render remaining.
-- Called after applying a change so stale ghost/strike
-- marks don't linger.
local function redraw_suggestions(bufnr)
  api.nvim_buf_clear_namespace(bufnr, ul_ns, 0, -1)
  local sugs = suggestions_cache[bufnr]
  if not sugs then return end
  for _, sug in ipairs(sugs) do
    if #sug.changes > 0 then
      render_suggestion(bufnr, sug)
    end
  end
end

local function apply_one_change(bufnr, sug)
  if #sug.changes == 0 then return false end
  local change = table.remove(sug.changes, 1)

  if change.kind == "modification" then
    -- Replace old line with new
    api.nvim_buf_set_lines(
      bufnr, change.lnum, change.lnum + 1,
      false, { change.new_text }
    )

  elseif change.kind == "insertion" then
    -- Insert new line after anchor
    local nl = change.lnum + 1
    api.nvim_buf_set_lines(
      bufnr, nl, nl, false, { change.new_text }
    )
    -- Cursor at end of newly inserted line
    local ec = math.max(0, #change.new_text - 1)
    api.nvim_win_set_cursor(0, { nl + 1, ec })

  elseif change.kind == "deletion" then
    -- Remove line entirely
    api.nvim_buf_set_lines(
      bufnr, change.lnum, change.lnum + 1,
      false, {}
    )
  end

  -- Record edit to blink-edit history for future
  -- prediction context
  local fp = api.nvim_buf_get_name(bufnr)
  if fp ~= "" then
    state.add_to_history(
      bufnr, fp,
      change.old_text or "",
      change.new_text or ""
    )
  end

  -- Remove this suggestion if fully consumed,
  -- then redraw remaining suggestions.
  if #sug.changes == 0 then
    local sugs = suggestions_cache[bufnr]
    if sugs then
      for i, s in ipairs(sugs) do
        if s == sug then
          table.remove(sugs, i)
          break
        end
      end
    end
  end
  redraw_suggestions(bufnr)

  return true
end

-- Find the suggestion with pending changes whose target
-- is closest to cursor, measured in characters (using
-- byte offset to get true distance across lines).
local function nearest_suggestion(bufnr)
  local sugs = suggestions_cache[bufnr]
  if not sugs then return nil end
  local cursor = api.nvim_win_get_cursor(0)
  local cur_off = api.nvim_buf_get_offset(
    bufnr, cursor[1] - 1
  ) + cursor[2]
  local best, best_dist
  for _, sug in ipairs(sugs) do
    if #sug.changes > 0 then
      local off = api.nvim_buf_get_offset(
        bufnr, sug.target_line - 1
      ) + sug.target_col
      local d = math.abs(off - cur_off)
      if not best or d < best_dist then
        best, best_dist = sug, d
      end
    end
  end
  return best
end

-- Global function for completion.nix Tab/Right keymaps
-- (insert mode). Finds suggestion nearest to cursor,
-- applies its first change.
-- Returns true if applied, false if nothing to do.
_G._blink_edit_apply_suggestion = function()
  local bufnr = api.nvim_get_current_buf()
  local best = nearest_suggestion(bufnr)
  if not best then return false end
  apply_one_change(bufnr, best)
  return true
end

-- ===========================================================
-- Visibility listeners (rendering entry point)
-- ===========================================================
-- blink-edit's render module calls on_show when a new
-- prediction is ready, on_clear when tearing down.

render.set_visibility_listeners({
  on_show = function(bufnr)
    -- Clear base + overlay extmarks
    api.nvim_buf_clear_namespace(
      bufnr, render.get_namespace(), 0, -1
    )
    api.nvim_buf_clear_namespace(bufnr, ul_ns, 0, -1)

    -- Decompose prediction → suggestions, cache + render
    local sugs = compute_suggestions(bufnr)
    suggestions_cache[bufnr] = sugs
    for _, sug in ipairs(sugs) do
      render_suggestion(bufnr, sug)
    end
  end,

  on_clear = function(bufnr)
    -- Clear extmarks but keep suggestions_cache alive.
    -- Tab can still cycle stale suggestions while a new
    -- prediction is in flight. Cache replaced atomically
    -- by next on_show, or cleaned when all consumed.
    api.nvim_buf_clear_namespace(bufnr, ul_ns, 0, -1)
  end,
})

-- ===========================================================
-- Tab in normal mode
-- ===========================================================
-- Two-phase interaction:
--   1. First Tab: jump to nearest suggestion target
--      (with jumplist mark)
--   2. Second Tab (cursor at target): apply first change
--
-- Uses eventignore + suppress_normal_move to prevent the
-- cursor jump from triggering "moved away → reject".

vim.keymap.set("n", "<Tab>", function()
  local bufnr = api.nvim_get_current_buf()

  -- Try cache first (may be stale but usable while new
  -- prediction loads). Fall back to computing fresh.
  local sugs = suggestions_cache[bufnr]
  if not sugs then
    local pred = state.get_prediction(bufnr)
    if not pred then
      -- No prediction, no cache → pass through to <C-i>
      api.nvim_feedkeys(
        api.nvim_replace_termcodes(
          "<C-i>", true, false, true
        ), "n", false
      )
      return
    end
    sugs = compute_suggestions(bufnr)
    suggestions_cache[bufnr] = sugs
  end

  -- Filter to suggestions with pending changes
  local live = {}
  for _, s in ipairs(sugs) do
    if #s.changes > 0 then table.insert(live, s) end
  end
  if #live == 0 then
    -- All consumed — clean up, pass through
    suggestions_cache[bufnr] = nil
    api.nvim_feedkeys(
      api.nvim_replace_termcodes(
        "<C-i>", true, false, true
      ), "n", false
    )
    return
  end

  local cursor = api.nvim_win_get_cursor(0)

  -- Phase 2: cursor at target → apply
  for _, sug in ipairs(live) do
    if cursor[1] == sug.target_line
       and cursor[2] == sug.target_col then
      apply_one_change(bufnr, sug)
      return
    end
  end

  -- Phase 1: jump to next target after cursor (wrap)
  local jump
  for _, sug in ipairs(live) do
    local after =
      sug.target_line > cursor[1]
      or (sug.target_line == cursor[1]
          and sug.target_col > cursor[2])
    if after and (not jump
        or sug.target_line < jump.target_line
        or (sug.target_line == jump.target_line
            and sug.target_col < jump.target_col))
    then
      jump = sug
    end
  end
  -- Wrap: all before/at cursor → first one
  if not jump then jump = live[1] end

  -- Jumplist mark so <C-o> returns
  vim.cmd("normal! m'")
  -- Suppress engine's "cursor moved → reject" logic
  state.set_suppress_normal_move(bufnr, true)
  -- Suppress CursorMoved autocmds during jump
  local saved_ei = vim.o.eventignore
  vim.o.eventignore =
    "CursorMoved,CursorMovedI,CursorHold,CursorHoldI"
  api.nvim_win_set_cursor(
    0, { jump.target_line, jump.target_col }
  )
  vim.schedule(function()
    vim.o.eventignore = saved_ei
  end)
end)

-- ===========================================================
-- null-ls code action
-- ===========================================================
-- Offers entire prediction as a single "apply all" action.
-- Replaces full context window in one shot.

require("null-ls").register({
  method = require("null-ls").methods.CODE_ACTION,
  filetypes = {},
  generator = {
    fn = function(params)
      local pred = state.get_prediction(params.bufnr)
      if not pred then return end
      local ws = pred.window_start
      return {{
        title = "blink-edit: apply suggestion",
        edit = {
          changes = {
            [vim.uri_from_bufnr(params.bufnr)] = {{
              range = {
                start = {
                  line = ws - 1,
                  character = 0,
                },
                ["end"] = {
                  line = ws - 1 + #pred.snapshot_lines,
                  character = 0,
                },
              },
              newText =
                table.concat(
                  pred.predicted_lines, "\n"
                ) .. "\n",
            }},
          },
        },
      }}
    end,
  },
})
