local mod = require('down.mod')
local log = require('down.log')
local Tag = require('down.mod.tag.tag')

---@class down.mod.tag.Tag: down.Mod
local Tag = mod.new 'tag'

---@class down.mod.tag.Commands: down.Commands
Tag.commands = {
  tag = {
    name = 'tag',
    condition = 'markdown',
    args = 0,
    max_args = 1,
    callback = function(e)
      log.trace 'tag.commands.tag: cb '
    end,
    commands = {
      delete = {
        name = 'data.tag.delete',
        condition = 'markdown',
        args = 0,
        max_args = 1,
        callback = function(e)
          log.trace 'tag.commands.tag.delete: cb '
        end,
      },
      new = {
        args = 0,
        max_args = 1,
        condition = 'markdown',
        callback = function(e)
          log.trace 'tag.commands.tag.new: cb '
        end,
        name = 'data.tag.new',
      },
      list = {
        name = 'data.tag.list',
        args = 0,
        max_args = 1,
        condition = 'markdown',
        callback = function(e)
          log.trace 'tag.commands.tag.list: cb '
        end,
      },
    },
  },
}
---@return down.mod.Setup
Tag.setup = function()
  return {
    loaded = true,
    dependencies = { 'workspace', 'cmd', 'data' },
  }
end

---@class (exact) down.Tag.Instance: {
---  tag: string,
---  line?: string,
---  position: down.Position,
---  path: string,
---  workspace?: string,
---}

---@class (exact) down.Tag.Instances: {
---  [string]: down.Tag.Instance[],
---}

---@class down.mod.tag.Data
Tag.tags = {
  ---@type down.Tag.Instances
  global = {},
  ---@type down.Tag.Instances
  workspace = {},
  ---@type down.Tag.Instances
  document = {},
}

--- Parse a single line for tag instances
--- @param ln string
--- @param lnno number
--- @param path string
--- @return string[]
Tag.parse_ln = function(ln)
  local tags = {}
  for tag in ln:gmatch '#%S+' do
    tags:insert(tag)
  end
  return tags
end

Tag.parse_current_ln = function()
  local ln = vim.api.nvim_buf_get_lines(0, pos[1] - 1, pos[1], false)
  local path = vim.fn.expand('%:p')
  local ws = Tag.dep['workspace'].get_current_workspace()
  local tags = {}
  for tag in ln:gmatch '#%S+' do
    table.insert(tags, { ---@type down.Tag.Instance
      tag = tag,
      workspace = ws,
      path = path,
      line = ln,
      position = {
        line = vim.api.nvim_get_current_line(),
        char = 0,
      },
    })
  end
  return tags
end

Tag.parse_current_doc = function()
  local tags = {}
  for i, ln in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    for tag in ln:gmatch '#%S+' do
      table.insert(tags, { ---@type down.Tag.Instance
        tag = tag,
        workspace = Tag.dep['workspace'].get_current_workspace(),
        path = vim.fn.expand('%:p'),
        line = ln,
        position = {
          line = i,
          col = 0,
        },
      })
    end
  end
  return tags
end

Tag.parse_current_workspace = function()
  local tags = {}
  for i, ln in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    for tag in ln:gmatch '#%S+' do
      table.insert(tags, { ---@type down.Tag.Instance
        tag = tag,
        workspace = Tag.dep['workspace'].get_current_workspace(),
        path = vim.fn.expand('%:p'),
        line = ln,
        position = {
          line = i,
          col = 0,
        },
      })
    end
  end
  return tags
end

Tag.parse = function(text)
  local tags = {}
  for ln in text:gmatch '[^\n]+' do
    vim.tbl_deep_extend('force', Tag.tags.document, Tag.parse_ln(ln))
  end
  return tags
end

Tag.parse_doc = function(path)
  local tags = {}
  local buf = assert(io.open(path, 'r'))
  for i, ln in ipairs(buf:lines()) do
  end
end

Tag.document_source = function(path) end

Tag.workspace_source = function(path) end

---@class down.mod.tag.Config
Tag.config = {}

-- ---@class down.mod..tag.Subscribed
-- Tag.handle = {
--   cmd = {
--     ['data.tag.delete'] = function(e) end,
--     ['data.tag.new'] = function(e) end,
--     ['data.tag.list'] = function(e) end,
--   },
-- }

return Tag
