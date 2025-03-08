local down = require('down')
local lib, mod, utils, log = down.lib, down.mod, down.utils, down.log

local Run = require 'down.mod'.new('code.run')

Run.setup = function()
  return {
    loaded = true,
  }
end

---@class down..code.run.Config
Run.config = {}

return Run
