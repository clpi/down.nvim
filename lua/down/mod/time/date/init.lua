local down = require 'down'
local mod = down.mod

---@class down.mod.time.date.Date: down.Mod
local Date = mod.new("time.date")

Date.setup = function()
  return {
    loaded = true,
  }
end

Date.load = function()

end

return Date
