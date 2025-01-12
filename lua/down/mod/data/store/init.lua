local down = require 'down'
local mod = down.mod

---@class down.mod.data.Store: down.Mod
local Store = mod.new 'data.store'

---@return down.mod.Setup
Store.setup = function()
  return {
    loaded = true,
    dependencies = {
      'data',
    },
  }
end

--- @class down.mod.data.store.Config
Store.config = {}

---@type down.mod.Handler
Store.handle = {}

return Store
