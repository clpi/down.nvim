local mod = require 'down.mod'
local log = require 'down.log'

---@class down.mod.ui.calendar.Day: down.Mod
local Day = mod.new 'ui.calendar.day'

---@return down.mod.Setup
Day.setup = function()
  return { ---@type down.mod.Setup
    loaded = true,
    dependencies = {},
  }
end

---@class down.mod.ui.calendar.day.Config
Day.config = {
  enabled = true
}

return Day
