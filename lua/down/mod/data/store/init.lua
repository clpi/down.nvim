local down = require 'down'
local mod = down.mod

---@class down.mod..Store: down.Mod
local Store = mod.new 'data.store'

Store.setup = function()
  return {
    loaded = true,
    dependencies = {
      'data',
    },
  }
end

--- @class down.mod..store.Config
Store.config = {}

---@type down.mod.Handler
Store.handle = {}

return Store
