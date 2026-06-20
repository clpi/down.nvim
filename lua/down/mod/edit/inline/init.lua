local log = require ("down.log")
local mod = require ("down.mod")

---@class down.mod.edit.inline.Inline: down.Mod
local Inline = mod.new ("edit.inline")
Inline.dep = { "lsp", "cmd" }

local ns = vim.api.nvim_create_namespace ("down.inline")

---@class down.mod.edit.inline.Config
Inline.config = {
  enabled = true,
  --- Debounce ms before requesting suggestions
  debounce_ms = 400,
  --- Minimum characters on current line before suggesting
  min_chars = 3,
  --- Use LSP down.inline.complete command
  use_lsp = true,
  --- Fall back to local semantic search when LSP unavailable
  use_semantic = true,
  --- Fall back to local knowledge graph
  use_knowledge = true,
  --- Keymap to accept ghost text
  accept_key = "<C-]>",
  --- Keymap to dismiss ghost text
  dismiss_key = "<C-g>",
}

Inline._timer = nil
Inline._suggestion = nil
Inline._buf = nil

--- Clear ghost text extmark from buffer
---@param bufnr? number
function Inline.clear (bufnr)
  bufnr = bufnr or Inline._buf or 0
  if bufnr == 0 or not vim.api.nvim_buf_is_valid (bufnr) then
    return
  end
  vim.api.nvim_buf_clear_namespace (bufnr, ns, 0, -1)
  Inline._suggestion = nil
end

--- Show ghost text at cursor position
---@param bufnr number
---@param line number 0-based
---@param col number 0-based
---@param text string
function Inline.show (bufnr, line, col, text)
  if not text or text == "" then
    Inline.clear (bufnr)
    return
  end
  Inline._buf = bufnr
  Inline._suggestion = { line = line, col = col, text = text }
  vim.api.nvim_buf_clear_namespace (bufnr, ns, line, line + 1)
  local display = text:gsub ("\n", " ↵ ")
  vim.api.nvim_buf_set_extmark (bufnr, ns, line, col, {
    virt_text = { { display, "Comment" } },
    virt_text_pos = "overlay",
    hl_mode = "combine",
    priority = 100,
  })
end

--- Accept the current ghost text suggestion
function Inline.accept ()
  local sug = Inline._suggestion
  if not sug or not Inline._buf then
    return false
  end
  local bufnr = Inline._buf
  local line = vim.api.nvim_buf_get_lines (bufnr, sug.line, sug.line + 1, false)[1]
    or ""
  local before = line:sub (1, sug.col)
  local after = line:sub (sug.col + 1)
  local insert = sug.text:gsub ("\n", "\n" .. string.rep (" ", sug.col))
  vim.api.nvim_buf_set_lines (
    bufnr,
    sug.line,
    sug.line + 1,
    false,
    { before .. insert .. after }
  )
  local new_col = #before + #insert
  vim.api.nvim_win_set_cursor (0, { sug.line + 1, new_col })
  Inline.clear (bufnr)
  return true
end

--- Local knowledge-graph continuation suggestions
---@param line_prefix string
---@return string|nil
local function knowledge_suggest (line_prefix)
  local ok, kg = pcall (require, "down.mod.data.knowledge")
  if not ok or not kg or not kg.entities then
    return nil
  end
  local words = {}
  for w in line_prefix:gmatch ("[%w_]+") do
    words[#words + 1] = w:lower ()
  end
  local term = words[#words]
  if not term or #term < 2 then
    return nil
  end
  for _, ent in pairs (kg.entities) do
    local name = (ent.name or ""):lower ()
    if
      name:find (term, 1, true)
      and not line_prefix:lower ():find (name, 1, true)
    then
      local kind = ent.kind or ""
      if kind == "tag" then
        return " #" .. ent.name
      elseif kind == "person" then
        return " @" .. ent.name
      else
        return " [[" .. ent.name .. "]]"
      end
    end
  end
  return nil
end

--- Local semantic search suggestion
---@param line_prefix string
---@return string|nil
local function semantic_suggest (line_prefix)
  local ok, semantic = pcall (require, "down.mod.data.semantic")
  if not ok or not semantic or not semantic.search then
    return nil
  end
  local query = line_prefix:gsub ("^%s+", "")
  if #query < 3 then
    return nil
  end
  local hits = semantic.search (query, { limit = 1, threshold = 0.4 })
  if hits[1] and hits[1].text then
    local snippet = hits[1].text:gsub ("\n", " "):sub (1, 80)
    if #snippet > #query then
      return snippet:sub (#query + 1)
    end
  end
  return nil
end

--- Request inline completion from LSP server
---@param bufnr number
---@param line number 0-based
local function request_lsp (bufnr, line)
  local clients = vim.lsp.get_clients ({ bufnr = bufnr, name = "down" })
  if #clients == 0 then
    return
  end
  local uri = vim.uri_from_bufnr (bufnr)
  vim.lsp.buf_request (bufnr, "workspace/executeCommand", {
    command = "down.inline.complete",
    arguments = { uri, line },
  }, function (err, result)
    if err or not result then
      return
    end
    local items = result
    if type (result) == "table" and result[1] then
      items = result
    end
    if type (items) ~= "table" or #items == 0 then
      return
    end
    local item = items[1]
    local text = item.insertText or item.insert_text
    if text and text ~= "" then
      local col = vim.api.nvim_win_get_cursor (0)[2]
      vim.schedule (function ()
        Inline.show (bufnr, line, col, text)
      end)
    end
  end)
end

--- Trigger inline suggestion for current cursor
function Inline.trigger ()
  if not Inline.config.enabled then
    return
  end
  local bufnr = vim.api.nvim_get_current_buf ()
  if
    vim.bo[bufnr].filetype ~= "markdown"
    and vim.bo[bufnr].filetype ~= "md"
    and vim.bo[bufnr].filetype ~= "down"
  then
    return
  end
  if vim.api.nvim_get_mode ().mode ~= "i" then
    return
  end

  local row, col = unpack (vim.api.nvim_win_get_cursor (0))
  local line = vim.api.nvim_buf_get_lines (bufnr, row - 1, row, false)[1] or ""
  local prefix = line:sub (1, col)
  if #vim.trim (prefix) < Inline.config.min_chars then
    Inline.clear (bufnr)
    return
  end

  -- Skip inside code blocks using treesitter detection
  local ok, codeblock = pcall (require, "down.mod.integration.codeblock")
  if ok and codeblock.is_inside (bufnr) then
    Inline.clear (bufnr)
    return
  end

  -- Local fallbacks (fast, synchronous)
  local suggestion = nil
  if Inline.config.use_knowledge then
    suggestion = knowledge_suggest (prefix)
  end
  if not suggestion and Inline.config.use_semantic then
    suggestion = semantic_suggest (prefix)
  end
  if suggestion then
    Inline.show (bufnr, row - 1, col, suggestion)
  end

  -- LSP AI/knowledge suggestions (async, may override)
  if Inline.config.use_lsp then
    request_lsp (bufnr, row - 1)
  end
end

--- Debounced trigger
function Inline.debounced_trigger ()
  if Inline._timer then
    vim.fn.timer_stop (Inline._timer)
  end
  Inline._timer = vim.fn.timer_start (Inline.config.debounce_ms, function ()
    Inline.trigger ()
  end)
end

Inline.setup = function ()
  if not Inline.config.enabled then
    return { loaded = true }
  end

  vim.api.nvim_create_autocmd ({ "InsertCharPre", "TextChangedI" }, {
    pattern = { "markdown", "md", "down" },
    callback = function ()
      Inline.debounced_trigger ()
    end,
    desc = "down inline AI suggestions",
  })

  vim.api.nvim_create_autocmd ({ "InsertLeave", "BufLeave", "CursorMovedI" }, {
    pattern = { "markdown", "md", "down" },
    callback = function (ev)
      if ev.event == "CursorMovedI" then
        Inline.debounced_trigger ()
        return
      end
      Inline.clear (ev.buf)
    end,
    desc = "down inline clear ghost text",
  })

  return { loaded = true }
end

Inline.commands = {
  inline = {
    enabled = true,
    args = 0,
    name = "inline",
    callback = function ()
      Inline.trigger ()
    end,
    commands = {
      accept = {
        enabled = true,
        args = 0,
        name = "inline.accept",
        callback = function ()
          Inline.accept ()
        end,
      },
      clear = {
        enabled = true,
        args = 0,
        name = "inline.clear",
        callback = function ()
          Inline.clear ()
        end,
      },
    },
  },
}

return Inline
