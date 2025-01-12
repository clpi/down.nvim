local mod = require('down.mod')

local M = mod.new('ui.prompt')

M.setup = function()
  return {
    loaded = true,
    dependencies = {},
  }
end

---@class down.ui.prompt.Config
M.config = {}

return M
