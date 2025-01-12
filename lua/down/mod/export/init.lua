---[[
---   A module for users to export their data
---]]

local down = require 'down'
local mod = down.mod
local util = down.util
local log = util.log

local Export = mod.new 'export'

Export.setup = function()
  return {
    loaded = true,
  }
end

Export.maps = function() end

Export.load = function() end

return Export
