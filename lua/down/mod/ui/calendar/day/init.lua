local mod = require 'down.mod'
local log = require 'down.util.log'

---@class down.mod.ui.calendar.Day: down.Mod
local D = mod.new 'ui.calendar.day'

---@return down.mod.Setup
D.setup = function()
  return { ---@type down.mod.Setup
    loaded = true,
    dependencies = {},
  }
end

---@class down.mod.ui.calendar.day.Config
D.config = {}

return D
