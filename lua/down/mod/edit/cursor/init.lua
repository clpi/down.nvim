local mod = require("down.mod")
local tbl = require("down.util.table")
local util = require("down.util")
local log = util.log
local ts = vim.treesitter
local tuok, tu = pcall(require, "nvim-treesitter.ts_utils")

---@class down.mod.edit.Cursor: down.Mod
local L = mod.new("edit.cursor")

---@return down.mod.Setup
function L.setup()
  return {
    dependencies = {
      "tool.treesitter",
      "workspace",
    },
    loaded = tuok,
  }
end

L.update = function(event)
  local cursor_record = tbl.orempty(M.cursor_record, event.buffer)
  cursor_record.row_0b = event.cursor_position[1] - 1
  cursor_record.col_0b = event.cursor_position[2]
  cursor_record.line_content = event.line_content
end

---@class down.mod.edit.cursor.Config
L.config = {}

---@class down.edit.cursor.Data
---@field public node TSNode|nil
---@field public text string[]
---@field public prev TSNode|nil
---@field public next TSNode|nil
---@field public root function|TSNode
---@field public children TSNode[]
---@field public captures function|string[]
---@field public range ...
---@field public lspRange table
---@field public hl nil
---@class edit.cursor.Node
L.node = {}

L.line = require("down.mod.edit.line")

L.cword = function()
  return vim.fn.expand("<cword>")
end

L.cWORD = function()
  return vim.fn.expand("<cWORD>")
end

function L.node:captures()
  return ts.get_captures_at_cursor(0)
end

---@return table
function L.node:lspRange()
  ---@diagnostic disable-next-line
  return tu.node_to_lsp_range(self.get())
end

---@param switch boolean: switch parent
---@param nextParent boolean: nextParent parent
---@return TSNode|nil
function L.node:next(switch, nextParent)
  ---@diagnostic disable-next-line
  return tu.get_next_node(self.get(), switch or true, nextParent or true)
end

---@param switch boolean: switch parent
---@param prevParent boolean: nextParent parent
---@return TSNode|nil
function L.node:prev(switch, prevParent)
  ---@diagnostic disable-next-line
  return tu.get_previous_node(self.get(), switch or true, prevParent or true)
end

---@return string[]
function L.node:text()
  ---@diagnostic disable-next-line
  return tu.get_node_text(self.get(), 0)
end

---@return TSNode|nil
function L.node.get()
  local n = tu.get_node_at_cursor(0, nil)
  ---@diagnostic disable-next-line
  setmetatable(n, { __index = n, __call = L.node.get() })
  return n
end

---@return TSNode
function L.node:root()
  ---@diagnostic disable-next-line
  return tu.get_root_for_node(self.get())
end

---@return ...
function L.node:range()
  ---@diagnostic disable-next-line
  return tu.get_vim_range(self.get(), 0)
end

---@param ns? string: namespace
---@param hgroup? string: hilite group
---@return nil
function L.node:hl(ns, hgroup)
  ---@diagnostic disable-next-line
  return tu.highlight_node(self.get(), 0, ns, hgroup)
end

---@return boolean
function L.in_codeblock()
  return false
end

return L
