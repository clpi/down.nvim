---[[
---   A module for users to define their own keymaps dynamically
---]]

local down = require 'down'
local mod = down.mod
local util = down.util
local log = util.log

---@class down.mod.Keymap: down.Mod
local K = mod.new 'keymap'

K.setup = function()
  return {
    loaded = true,
  }
end

K.maps = function() end

K.load = function() end

return K
