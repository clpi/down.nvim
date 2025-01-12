local mod = require 'down.mod'
local log = require 'down.util.log'

local P = mod.new 'parse'

P.setup = function()
  return {
    loaded = true,
    dependencies = {
      'data',
      'tool.treesitter',
    },
  }
end

P.load = function() end

---@class down.mod.parse.Config
P.config = {}

return P
