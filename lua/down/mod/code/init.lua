local mod = require 'down.mod'
local log = require 'down.util.log'

--- @class down.mod.Code: down.Mod
local Code = mod.new('code', { 'snippet', 'run' })

--- @class down.mod.code.Config
---   @field languages string[]
Code.config = {
  --- What languages to support
  languages = {},
}

---@type table<string, string>
Code.code = {}

Code.commands = {
  code = {
    name = 'code',
    condition = 'markdown',
    args = 1,
    callback = function(e)
      log.trace(('Code.commands.code callback: %s'):format(e.body))
    end,
    subcommands = {
      edit = {
        args = 0,
        condition = 'markdown',
        callback = function(e)
          log.trace(('Code.commands.edit cb: %s'):format(e.body))
        end,
        name = 'code.edit',
      },
      run = {
        args = 0,
        condition = 'markdown',
        callback = function(e)
          log.trace(('Code.commands.run cb: %s'):format(e.body))
        end,
        name = 'code.run',
      },
      save = {
        args = 0,
        condition = 'markdown',
        callback = function(e)
          log.trace(('Code.commands.save cb: %s'):format(e.body))
        end,
        name = 'code.save',
      },
    },
  },
}

Code.load = function() end

Code.setup = function()
  return {
    loaded = true,
    dependencies = {
      'cmd',
      'data',
      'workspace',
    },
  }
end

return Code
