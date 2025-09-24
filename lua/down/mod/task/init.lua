local mod = require 'down.mod'
local log = require 'down.log'

---@class down.mod.Task: down.Taskod
local Task = mod.new('task')

---@class down.mod.task.Task
Task.Task = {
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
Task.tasks = {}

---@class down.mod.task.Config
Task.config = {
  store = {
    root = 'data/task',
    agenda = 'data/task/agenda',
  },
}

Task.commands = {
  task = {
    name = 'task',
    args = 0,
    condition = 'markdown',
    enabled = true,
    max_args = 1,
    callback = function(e)
      log.trace 'task'
    end,
    commands = {
      toggle = {
        name = 'task.toggle',
        enabled = true,
        args = 0,
        max_args = 1,
        callback = function(e)
          log.trace 'task.toggle'
          Task.toggle()
        end,
      },
      list = {
        args = 0,
        max_args = 1,
        name = 'task.list',
        callback = function(e)
          log.trace 'task.list'
        end,
        commands = {
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

Task.load = function() end

---@return down.mod.Setup
Task.setup = function()
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

function Task.toggle()
  local line = vim.api.nvim_get_current_line()
  if line:match('%[ %]') then
    line = line:gsub('%[ %]', '[x]')
  elseif line:match('%[x%]') then
    line = line:gsub('%[x%]', '[ ]')
  end
  vim.api.nvim_set_current_line(line)
end

-- Task.handle = {
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

return Task
