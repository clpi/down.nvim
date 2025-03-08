local down = require 'down'
local mod  = down.mod

local Time = mod.new("time", { 'date' })

---@return down.mod.Setup
Time.setup = function()
  return {
    loaded = true,
    dependencies = {
      "cmd",
    }
  }
end

return Time
