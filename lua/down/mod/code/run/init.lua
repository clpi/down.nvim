local down = require('down')
local lib, mod, utils, log = down.lib, down.mod, down.utils, down.log

local M = require 'down.mod'.new('code.run')

M.setup = function()
  return {
    loaded = true,
  }
end

---@class down..code.run.Config
M.config = {}

return M
