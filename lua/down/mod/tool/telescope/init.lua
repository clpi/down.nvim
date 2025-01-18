local mod = require 'down.mod'
local log = require 'down.util.log'

---@class down.mod.tool.Telescope: down.Mod
local M = mod.new 'tool.telescope'
local tok, t = pcall(require, 'telescope')

---@return down.mod.Setup
M.setup = function()
  return {
    loaded = tok,
    dependencies = { 'workspace' },
  }
end

---@class down.mod.tool.telescope.Config: down.Mod.Config
M.config = {
  enabled = {
    'files',
    'tags',
    'links',
    -- "insert_link",
    -- "insert_file_link",
    -- "search_headings",
    -- "find_project_tasks",
    -- "find_aof_project_tasks",
    -- "find_aof_tasks",
    -- "find_context_tasks",
    'workspace',
    -- "backlinks.file_backlinks",
    -- "backlinks.header_backlinks",
  },
}
---@class down.mod.tool.telescope.Config: down.mod.Config
M.config = {
  enabled = {
    ['backlinks'] = true,
    ['workspace'] = true,
    ['files'] = true,
    ['tags'] = true,
    ['links'] = true,
    ['grep'] = true,
  },
}

M.pickers = {}
M.load_pickers = function()
  local r = {}
  for _, pic in ipairs(M.config.enabled) do
    local ht, te = pcall(require, 'telescope._extensions.down.picker.' .. pic)
    if ht then
      r[pic] = te
    end
    r[pic] = require('telescope._extensions.down.picker.' .. pic)
  end
  M.pickers = r
  return r
end
M.commands = {
  find = {
    args = 0,
    name = 'find',
    callback = require 'telescope._extensions.down.picker.files',
    subcommands = {
      links = {
        callback = require 'telescope._extensions.down.picker.links',
        name = 'find.links',
        args = 0,
      },
      tags = {
        callback = require 'telescope._extensions.down.picker.tags',
        name = 'find.tags',
        args = 0,
      },
      files = {
        callback = require 'telescope._extensions.down.picker.files',
        name = 'find.files',
        args = 0,
      },
      workspace = {
        callback = require 'telescope._extensions.down.picker.workspace',
        name = 'find.workspace',
        args = 0,
      },
    },
  },
}
M.load = function()
  assert(tok)
  M.load_pickers()
  if tok then
    t.load_extension 'down'
    for _, pic in ipairs(M.config.enabled) do
      vim.keymap.set('n', '<plug>down.telescope.' .. pic .. '', M.pickers[pic])
    end
  else
    return
  end
end

M.maps = {
  { 'n', ',dF', '<cmd>Telescope down files<CR>', 'Telescope down files' },
  { 'n', ',dF', '<cmd>Telescope down<CR>', 'Telescope down' },
  { 'n', ',dL', '<cmd>Telescope down links<CR>', 'Telescope down links' },
  { 'n', ',dW', '<cmd>Telescope down workspace<CR>', 'Telescope down workspaces' },
  -- { 'n', ',dt', '<cmd>Telescope down tags<CR>',      'Telescope down tags' },
}

-- M.handle = {
--   cmd = {
--     ['find'] =
--     ['find.files'] = require('telescope._extensions.down.picker.files'),
--     ['find.tags'] = require('telescope._extensions.down.picker.tags'),
--     ['find.workspace'] = require('telescope._extensions.down.picker.workspace'),
--     ['find.links'] = require('telescope._extensions.down.picker.links'),
--   },
-- }

return M
