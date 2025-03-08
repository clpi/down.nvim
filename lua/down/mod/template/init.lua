local config = require 'down.config'
local util = require 'down.util'
local log = require 'down.util.log'
local mod = require 'down.mod'
local sep = util.sep

---@class down.mod.template.Template: down.Mod
local Template = mod.new 'template'

Template.commands = {
  template = {
    min_args = 1,
    enabled = false,
    max_args = 2,
    name = 'template',
    callback = Template.create_template,
    commands = {
      index = {
        enabled = false,
        callback = Template.open_index,
        args = 0,
        name = 'template.index',
      },
      month = {
        max_args = 1,
        enabled = false,
        name = 'template.month',
        callback = Template.open_month,
      },
      tomorrow = {
        callback = Template.template_tomorrow,
        enabled = false,
        args = 0,
        name = 'template.tomorrow',
      },
      yesterday = {
        args = 0,
        enabled = false,
        name = 'template.yesterday',
        Template.template_yesterday,
      },
      today = {
        args = 0,
        name = 'template.today',
        callback = Template.template_today,
        enabled = false,
      },
      custom = {
        callback = Template.create_template,
        max_args = 1,
        enabled = false,
        name = 'template.custom',
      }, -- format :yyyy-mm-dd
      template = {
        callback = Template.create_template,
        enabled = false,
        args = 0,
        name = 'template.template',
      },
    },
  },
}

Template.load = function()
  if Template.config.strategies[Template.config.strategy] then
    Template.config.strategy = Template.config.strategies[Template.config.strategy]
  end
end
Template.setup = function()
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
Template.config = {
  strategies = {
    flat = '%Y-%m-%d.md',
    nested = '%Y' .. sep .. '%m' .. sep .. '%d.md',
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
  -- Templateay be "flat" (`2022-03-02.down`), "nested" (`2022/03/02.down`),
  -- a lua string with the format given to `os.date()` or a lua function
  -- that returns a lua string with the same format.
  strategy = 'nested',

  -- The name of the template file to use when running `:down template template`.
  template_name = 'template.md',

  -- Whether to apply the template file to new template entries.
  use_template = true,
}

---@class down.mod.template.Data

Template.open_month = function() end
Template.open_index = function() end
--- Opens a template entry at the given time
---@param time? number #The time to open the template entry at as returned by `os.time()`
---@param custom_date? string #A YYYY-mm-dd string that specifies a date to open the template at instead
Template.open_template = function(time, custom_date)
  local workspace = Template.config.workspace or Template.dep['workspace'].get_current_workspace()[1]
  local workspace_path = Template.dep['workspace'].get_workspace(workspace)
  local folder_name = Template.config.template_folder
  local template_name = Template.config.template_name

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
    type(Template.config.strategy) == 'function' and Template.config.strategy(os.date('*t', time))
    or Template.config.strategy,
    time
  )

  local template_file_exists = Template.dep['workspace'].file_exists(
    workspace_path .. sep .. folder_name .. sep .. path
  )

  Template.dep['workspace'].new_file(folder_name .. sep .. path, workspace)

  Template.dep['workspace'].new_file(folder_name .. sep .. path, workspace)

  if
      not template_file_exists
      and Template.config.use_template
      and Template.dep['workspace'].file_exists(
        workspace_path .. sep .. folder_name .. sep .. template_name
      )
  then
    vim.cmd(
      '$read '
      .. workspace_path
      .. sep
      .. folder_name
      .. sep
      .. template_name
      .. '| silent! w'
    )
  end
end

--- Opens a template entry for tomorrow's date
Template.template_tomorrow = function()
  Template.open_template(os.time() + 24 * 60 * 60)
end

--- Opens a template entry for yesterday's date
Template.template_yesterday = function()
  Template.open_template(os.time() - 24 * 60 * 60)
end

--- Opens a template entry for today's date
Template.template_today = function()
  Template.open_template()
end

--- Creates a template file
Template.create_template = function()
  local workspace = Template.config.workspace
  local folder_name = Template.config.template_folder
  local template_name = Template.config.template_name

  Template.dep.workspace.new_file(
    folder_name .. sep .. template_name,
    workspace or Template.dep.workspace.get_current_workspace()[1]
  )
end

-- Template.handle = {
--   cmd = {
--     ['template.index'] = Template.open_index,
--     ['template.month'] = Template.open_month,
--     ['template.tomorrow'] = Template.template_tomorrow,
--     ['template.yesterday'] = Template.template_yesterday,
--     ['template.custom'] = Template.open_template,
--     ['template.today'] = Template.template_today,
--     ['template.template'] = Template.create_template,
--   },
-- }

return Template
