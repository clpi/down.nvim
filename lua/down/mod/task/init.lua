local mod = require 'down.mod'
local log = require 'down.util.log'

---@class down.mod.Task: down.Mod
local M = mod.new('task')

---@class down.mod.task.Task
M.Task = {
  title = '',
  about = '',
  status = 0,
  due = '',
  created = '',
  uri = '',
  ---@type down.Position
  pos = {
    line = -1,
    char = -1,
  },
}

---@class table<integer, down.mod.task.Task>
M.tasks = {}

---@class down.mod.task.Config
M.config = {
  store = {
    root = 'data/task',
    agenda = 'data/task/agenda',
  },
}

M.commands = {
  enabled = true,
  task = {
    name = 'task',
    args = 0,
    condition = 'markdown',
    max_args = 1,
    callback = function(e)
      log.trace 'task'
    end,
    subcommands = {
      toggle = {
        name = 'task.toggle',
        args = 0,
        max_args = 1,
        callback = function(e)
          log.trace 'task.toggle'
          M.toggle()
        end,
      },
      list = {
        args = 0,
        max_args = 1,
        name = 'task.list',
        callback = function(e)
          log.trace 'task.list'
        end,
        subcommands = {
          today = {
            name = 'task.list.today',
            args = 0,
            max_args = 1,
            callback = function(e)
              log.trace 'task.list.today'
            end,
          },
          recurring = {
            name = 'task.list.recurring',
            args = 0,
            max_args = 1,
            callback = function(e)
              log.trace 'task.list.recurring'
            end,
          },
          todo = {
            name = 'task.list.todo',
            args = 0,
            max_args = 1,
            callback = function(e)
              log.trace 'task.list.todo'
            end,
          },
          done = {
            name = 'task.list.done',
            args = 0,
            max_args = 1,
            callback = function(e)
              log.trace 'task.list.done'
            end,
          },
        },
      },
      add = {
        name = 'task.add',
        callback = function(e)
          log.trace 'task.add'
        end,
        args = 1,
        min_args = 0,
        max_args = 2,
      },
    },
  },
}

M.load = function() end

---@return down.mod.Setup
M.setup = function()
  ---@type down.mod.Setup
  return {
    dependencies = {
      'workspace',
      'cmd',
      'ui.calendar',
      'data.store',
      -- 'data.task.agenda',
    },
    loaded = true,
  }
end

function M.toggle()
  local line = vim.api.nvim_get_current_line()
  if line:match('%[ %]') then
    line = line:gsub('%[ %]', '[x]')
  elseif line:match('%[x%]') then
    line = line:gsub('%[x%]', '[ ]')
  end
  vim.api.nvim_set_current_line(line)
end

-- M.handle = {
--   cmd = {
--     ['task.list'] = function()
--       print('task.list')
--     end,
--     ['task.list.today'] = function()
--       print('task.list.today')
--     end,
--     ['task.list.recurring'] = function()
--       print('task.list.recurring')
--     end,
--     ['task.list.todo'] = function()
--       print('task.list.todo')
--     end,
--     ['task.list.done'] = function()
--       print('task.list.done')
--     end,
--     ['task.add'] = function()
--       print('task.add')
--     end,
--   },
-- }

return M
