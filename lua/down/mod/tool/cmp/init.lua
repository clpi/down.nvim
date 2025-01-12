local log = require 'down.util.log'
local mod = require 'down.mod'

local plenok, plenary = pcall(require, 'plenary.scandir').scan_dir
local cmpok, cmp = pcall(require, 'cmp')
local scan = plenary.scandir.scan_dir

---@class down.mod.tool.Cmp: down.Mod
local M = mod.new 'tool.cmp'

M.clean = function(s)
  if not s then
    return s
  end
  s = s:gsub('\n', ' ')
  return s:gsub('%s%s+', ' ')
end

---@class down.mod.tool.cmp.Data
M.files = function()
  local items = {}
  local root = M.dep['workspace'].get_current_workspace()[2]
  local ext = mod.mod_config 'workspace'.ext or '.md'
  for f, path in pairs(scan(root)) do
    if vim.endswith(path, ext) then
      local item = {
        path = path,
        label = path:match('([^/^\\]+)' .. ext .. '$'),
        kind = cmp.lsp.CompletionItemKind.File,
      }
      item.insertText = '[' .. item.label .. '](' .. item.path .. ')'
      local binary = assert(io.open(item.path, 'rb'))
      local kb = binary:read(1024)
      item.documentation = {
        kind = cmp.lsp.MarkupKind.Markdown,
        value = kb,
      }
      binary:close()
      local body = {}
      if kb then
        for b in kb:gmatch('[^\r\n1]+') do
          table.insert(body, b)
        end
      end
      table.insert(items, item)
    end
  end
  return items
end

M.tags = function()
  local tags = {}
  local root = M.dep['workspace'].get_current_workspace()[2]
end

---@class down.mod.tool.cmp.Config
M.config = {}

---@return down.mod.Setup
M.setup = function()
  if plenok and cmpok then
    return {
      loaded = true,
      dependencies = { 'workspace', 'tag', 'data', 'tool.treesitter' },
    }
  elseif plenok then
    return {
      loaded = true,
      dependencies = { 'workspace', 'tag', 'data', 'tool.treesitter' },
    }
  else
    return { loaded = false }
  end
end

M.load = function() end

return M
