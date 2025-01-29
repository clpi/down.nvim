local down = require 'down'
local mod  = down.mod

local T    = mod.new("time", { 'date' })

---@return down.mod.Setup
T.setup    = function()
  return {
    loaded = true,
    dependencies = {
      "cmd",
    }
  }
end

T.
    r
return T
