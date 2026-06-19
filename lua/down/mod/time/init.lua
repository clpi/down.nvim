local down = require 'down'
local mod  = down.mod

local Time = mod.new("time", { 'date' })
Time.dep = { "cmd" }

---@return down.mod.Setup
Time.setup = function()
  return {
    loaded = true,
  }
end

return Time
