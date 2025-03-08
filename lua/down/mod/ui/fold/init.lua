local mod = require 'down.mod'

--- @class down.mod.ui.fold.Fold: down.Mod
local Fold = mod.new 'ui.fold'

Fold.setup = function()
  return {
    loaded = true,
  }
end

---@class down.edit.fold.Config
Fold.config = {}

return Fold
