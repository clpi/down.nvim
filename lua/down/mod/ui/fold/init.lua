local mod = require 'down.mod'

local F = mod.new 'ui.fold'

F.setup = function()
  return {
    loaded = true,
  }
end

---@class down.edit.fold.Config
F.config = {}

return F
