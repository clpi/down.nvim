--- down.mod.footnote - org-footnote parity for markdown.
--- Markdown footnotes use `[^id]` references and `[^id]: definition` lines.
--- This mod provides jump-to-definition/reference, add (create ref + def), and
--- list, wired as `:Down footnote` subcommands.
---
--- Reference syntax:   `[^id]`           (id is one or more non-space, non-`]`)
--- Definition syntax: `[^id]: text...`   (a line whose first token is `[^id]:`)

local log = require ("down.log")
local mod = require ("down.mod")

local api = vim.api

---@class down.mod.footnote.Footnote: down.Mod
local Footnote = mod.new ("footnote")
Footnote.dep = { "cmd" }

---@class down.mod.footnote.Config
Footnote.config = {
  --- Where to display the footnote list: "split" | "vsplit" | "tab" | "echo".
  output = "split",
  --- Style for generated footnote ids: "numeric" (1,2,3) | "fn" (fn:1).
  id_style = "numeric",
}

--- Pattern matching a footnote reference token `[^id]`.
local REF_PAT = "%[%^([^%]]+)%]"
--- Pattern matching a footnote definition line `[^id]: text`.
local DEF_PAT = "^%s*%[%^([^%]]+)%]:%s*(.*)$"

---@class down.mod.footnote.Info
---@field refs table<string, number[]>  id -> list of (1-indexed) ref line numbers
---@field defs table<string, { line: number, text: string }>  id -> def info

--- Scan a buffer's lines and collect footnote references and definitions.
---@param bufnr number
---@return down.mod.footnote.Info
function Footnote.scan (bufnr)
  bufnr = bufnr or 0
  local lines = api.nvim_buf_get_lines (bufnr, 0, -1, false)
  local refs = {}
  local defs = {}
  for lno, line in ipairs (lines) do
    local did, text = line:match (DEF_PAT)
    local start_col = 1
    if did then
      defs[did] = { line = lno, text = text or "" }
      -- don't treat the `[^id]:` marker as a reference; scan refs after it
      local marker_end = line:find ("]:", 1, true)
      start_col = marker_end and (marker_end + 1) or 1
    end
    local col = start_col
    while col <= #line do
      local _, e, id = line:find (REF_PAT, col)
      if not id then
        break
      end
      refs[id] = refs[id] or {}
      refs[id][#refs[id] + 1] = lno
      col = e + 1
    end
  end
  return { refs = refs, defs = defs }
end

--- All distinct footnote ids (union of refs and defs), sorted.
---@param info down.mod.footnote.Info
---@return string[]
local function all_ids (info)
  local set = {}
  for id in pairs (info.refs) do
    set[id] = true
  end
  for id in pairs (info.defs) do
    set[id] = true
  end
  local ids = {}
  for id in pairs (set) do
    ids[#ids + 1] = id
  end
  table.sort (ids)
  return ids
end

--- Pick the next free footnote id.
---@param info down.mod.footnote.Info
---@return string
function Footnote.next_id (info)
  local used = {}
  for id in pairs (info.refs) do
    used[id] = true
  end
  for id in pairs (info.defs) do
    used[id] = true
  end
  if Footnote.config.id_style == "fn" then
    local n = 1
    while used["fn:" .. n] do
      n = n + 1
    end
    return "fn:" .. n
  end
  local n = 1
  while used[tostring (n)] do
    n = n + 1
  end
  return tostring (n)
end

--- Find the `[^id]` reference nearest the cursor on the current line.
---@param line string
---@param col number  1-indexed cursor column
---@return string|nil id, number|nil start_col, number|nil end_col
local function ref_at (line, col)
  local c = 1
  local best
  while c <= #line do
    local s, e, id = line:find (REF_PAT, c)
    if not id then
      break
    end
    if col >= s and col <= e + 1 then
      return id, s, e
    end
    best = best or { id = id, s = s, e = e }
    c = e + 1
  end
  if best then
    return best.id, best.s, best.e
  end
  return nil
end

--- Set cursor to a 1-indexed line (and column 1), in the window showing bufnr.
---@param bufnr number
---@param line number
local function goto_line (bufnr, line)
  for _, w in ipairs (api.nvim_list_wins ()) do
    if api.nvim_win_get_buf (w) == bufnr then
      api.nvim_set_current_win (w)
      api.nvim_win_set_cursor (w, { line, 0 })
      return
    end
  end
  api.nvim_win_set_cursor (0, { line, 0 })
end

--- Jump between a footnote reference and its definition (and back).
--- With the cursor on `[^id]`, goes to the `[^id]:` definition; on a
--- definition line, goes to the first reference.
---@param bufnr number
Footnote.jump = function (bufnr)
  bufnr = bufnr or 0
  local info = Footnote.scan (bufnr)
  local row, col = unpack (api.nvim_win_get_cursor (0))
  local line = api.nvim_buf_get_lines (bufnr, row - 1, row, false)[1] or ""
  local did, dtext = line:match (DEF_PAT)
  if did and dtext ~= nil then
    -- we're on a definition line: jump to the first reference
    local refs = info.refs[did]
    if refs and refs[1] then
      goto_line (bufnr, refs[1])
    else
      vim.notify (
        "[down] no references to footnote [^" .. did .. "]",
        vim.log.levels.WARN
      )
    end
    return
  end
  local id = ref_at (line, col)
  if not id then
    vim.notify ("[down] no footnote at cursor", vim.log.levels.WARN)
    return
  end
  local def = info.defs[id]
  if def then
    goto_line (bufnr, def.line)
  else
    vim.notify (
      "[down] footnote [^" .. id .. "] has no definition",
      vim.log.levels.WARN
    )
  end
end

--- Add a new footnote at the cursor: inserts `[^id]` after the cursor and a
--- `[^id]: ` definition line at the end of the file, leaving the cursor in
--- insert mode on the definition text.
---@param bufnr number
Footnote.add = function (bufnr)
  bufnr = bufnr or 0
  local info = Footnote.scan (bufnr)
  local id = Footnote.next_id (info)
  local token = "[^" .. id .. "]"
  local row, col = unpack (api.nvim_win_get_cursor (0))
  local line = api.nvim_buf_get_lines (bufnr, row - 1, row, false)[1] or ""
  -- insert the reference token right after the cursor column
  local before = line:sub (1, col)
  local after = line:sub (col + 1)
  local new_line = before .. token .. after
  api.nvim_buf_set_lines (bufnr, row - 1, row, false, { new_line })
  -- append the definition at the end of the file
  local count = api.nvim_buf_line_count (bufnr)
  local last = api.nvim_buf_get_lines (bufnr, count - 1, count, false)[1] or ""
  local insert = {}
  if last ~= "" then
    insert[#insert + 1] = ""
  end
  insert[#insert + 1] = ""
  insert[#insert + 1] = token .. ": "
  api.nvim_buf_set_lines (bufnr, count, count, false, insert)
  -- move the cursor onto the new definition line, in insert mode
  local def_row = count + #insert
  goto_line (bufnr, def_row)
  api.nvim_win_set_cursor (0, { def_row, #token + 2 })
  vim.cmd ("startinsert!")
  log.trace ("footnote.add", id)
end

--- List every footnote in the buffer with its definition preview and the
--- number of references.
---@param bufnr number
Footnote.list = function (bufnr)
  bufnr = bufnr or 0
  local info = Footnote.scan (bufnr)
  local ids = all_ids (info)
  if #ids == 0 then
    vim.notify ("[down] no footnotes in buffer", vim.log.levels.INFO)
    return
  end
  local lines = { string.format ("%d footnote(s):", #ids) }
  for _, id in ipairs (ids) do
    local def = info.defs[id]
    local refn = info.refs[id] and #info.refs[id] or 0
    local preview = def and def.text or "(missing definition)"
    if #preview > 60 then
      preview = preview:sub (1, 57) .. "..."
    end
    lines[#lines + 1] =
      string.format ("  [^%s]  %dx ref  %s", id, refn, preview)
  end
  local content = table.concat (lines, "\n")
  local target = Footnote.config.output
  if target == "echo" then
    print (content)
    return
  end
  local cmd = target == "vsplit" and "vsplit"
    or target == "tab" and "tabnew"
    or "split"
  vim.cmd (cmd)
  local buf = api.nvim_get_current_buf ()
  api.nvim_buf_set_lines (
    buf,
    0,
    -1,
    false,
    vim.split (content, "\n", { plain = true })
  )
  vim.bo[buf].filetype = "down.output"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  api.nvim_buf_set_name (buf, "down://footnote-list")
end

Footnote.setup = function ()
  return { loaded = true }
end

--- `:Down footnote` subcommands.
Footnote.commands = {
  footnote = {
    name = "footnote",
    args = 0,
    max_args = math.huge,
    condition = "markdown",
    callback = function (_e)
      Footnote.jump (api.nvim_get_current_buf ())
    end,
    commands = {
      jump = {
        name = "footnote.jump",
        args = 0,
        callback = function ()
          Footnote.jump (api.nvim_get_current_buf ())
        end,
      },
      add = {
        name = "footnote.add",
        args = 0,
        callback = function ()
          Footnote.add (api.nvim_get_current_buf ())
        end,
      },
      list = {
        name = "footnote.list",
        args = 0,
        callback = function ()
          Footnote.list (api.nvim_get_current_buf ())
        end,
      },
    },
  },
}

Footnote.maps = {
  {
    "n",
    "<leader>dfo",
    "<CMD>Down footnote<CR>",
    { desc = "down: jump footnote ref<->def" },
  },
  {
    "n",
    "<leader>dfa",
    "<CMD>Down footnote add<CR>",
    { desc = "down: add a footnote at cursor" },
  },
  {
    "n",
    "<leader>dfl",
    "<CMD>Down footnote list<CR>",
    { desc = "down: list footnotes" },
  },
}

Footnote.handle = {}

return Footnote
