local config = require 'down.config'
local log = require 'down.util.log'
local mod = require 'down.mod'

---@class down.mod.template: down.Mod
local M = mod.new 'template'

M.commands = {
  enabled = false,
  template = {
    min_args = 1,
    enabled = false,
    max_args = 2,
    name = 'template',
    callback = M.create_template,
    subcommands = {
      index = {
        enabled = false,
        callback = M.open_index,
        args = 0,
        name = 'template.index',
      },
      month = {
        max_args = 1,
        enabled = false,
        name = 'template.month',
        callback = M.open_month,
      },
      tomorrow = {
        callback = M.template_tomorrow,
        enabled = false,
        args = 0,
        name = 'template.tomorrow',
      },
      yesterday = {
        args = 0,
        enabled = false,
        name = 'template.yesterday',
        M.template_yesterday,
      },
      today = {
        args = 0,
        name = 'template.today',
        callback = M.template_today,
        enabled = false,
      },
      custom = {
        callback = M.create_template,
        max_args = 1,
        enabled = false,
        name = 'template.custom',
      }, -- format :yyyy-mm-dd
      template = {
        callback = M.create_template,
        enabled = false,
        args = 0,
        name = 'template.template',
      },
    },
  },
}

M.load = function()
  if M.config.strategies[M.config.strategy] then
    M.config.strategy = M.config.strategies[M.config.strategy]
  end
end
M.setup = function()
  return {
    loaded = true,
    dependencies = {
      'cmd',
      'workspace',
      'tool.treesitter',
    },
  }
end

---@class (exact) down.mod.template.Config
M.config = {
  strategies = {
    flat = '%Y-%m-%d.md',
    nested = '%Y' .. config.pathsep .. '%m' .. config.pathsep .. '%d.md',
  },
  -- Which workspace to use for the template files, the base behaviour
  -- is to use the current workspace.
  --
  -- It is recommended to set this to a static workspace, but the most optimal
  -- behaviour may vary from workflow to workflow.
  workspace = nil,

  -- The name for the folder in which the template files are put.
  template_folder = 'template',

  -- The strategy to use to create directories.
  -- May be "flat" (`2022-03-02.down`), "nested" (`2022/03/02.down`),
  -- a lua string with the format given to `os.date()` or a lua function
  -- that returns a lua string with the same format.
  strategy = 'nested',

  -- The name of the template file to use when running `:down template template`.
  template_name = 'template.md',

  -- Whether to apply the template file to new template entries.
  use_template = true,
}

---@class down.mod.template.Data

M.open_month = function() end
M.open_index = function() end
--- Opens a template entry at the given time
---@param time? number #The time to open the template entry at as returned by `os.time()`
---@param custom_date? string #A YYYY-mm-dd string that specifies a date to open the template at instead
M.open_template = function(time, custom_date)
  local workspace = M.config.workspace or M.dep['workspace'].get_current_workspace()[1]
  local workspace_path = M.dep['workspace'].get_workspace(workspace)
  local folder_name = M.config.template_folder
  local template_name = M.config.template_name

  if custom_date then
    local year, month, day = custom_date:match('^(%d%d%d%d)-(%d%d)-(%d%d)$')

    if not year or not month or not day then
      log.error('Wrong date format: use YYYY-mm-dd')
      return
    end

    time = os.time({
      year = year,
      month = month,
      day = day,
    })
  end

  local path = os.date(
    type(M.config.strategy) == 'function' and M.config.strategy(os.date('*t', time))
    or M.config.strategy,
    time
  )

  local template_file_exists = M.dep['workspace'].file_exists(
    workspace_path .. config.pathsep .. folder_name .. config.pathsep .. path
  )

  M.dep['workspace'].new_file(folder_name .. config.pathsep .. path, workspace)

  M.dep['workspace'].new_file(folder_name .. config.pathsep .. path, workspace)

  if
      not template_file_exists
      and M.config.use_template
      and M.dep['workspace'].file_exists(
        workspace_path .. config.pathsep .. folder_name .. config.pathsep .. template_name
      )
  then
    vim.cmd(
      '$read '
      .. workspace_path
      .. config.pathsep
      .. folder_name
      .. config.pathsep
      .. template_name
      .. '| silent! w'
    )
  end
end

--- Opens a template entry for tomorrow's date
M.template_tomorrow = function()
  M.open_template(os.time() + 24 * 60 * 60)
end

--- Opens a template entry for yesterday's date
M.template_yesterday = function()
  M.open_template(os.time() - 24 * 60 * 60)
end

--- Opens a template entry for today's date
M.template_today = function()
  M.open_template()
end

--- Creates a template file
M.create_template = function()
  local workspace = M.config.workspace
  local folder_name = M.config.template_folder
  local template_name = M.config.template_name

  M.dep.workspace.new_file(
    folder_name .. config.pathsep .. template_name,
    workspace or M.dep.workspace.get_current_workspace()[1]
  )
end

-- M.handle = {
--   cmd = {
--     ['template.index'] = M.open_index,
--     ['template.month'] = M.open_month,
--     ['template.tomorrow'] = M.template_tomorrow,
--     ['template.yesterday'] = M.template_yesterday,
--     ['template.custom'] = M.open_template,
--     ['template.today'] = M.template_today,
--     ['template.template'] = M.create_template,
--   },
-- }

return M
