local mod = require 'down.mod'

---@class down.mod.edit.Inline: down.Mod
local M = mod.new 'edit.inline'

M.setup = function()
  return {
    loaded = true,
  }
end

---@class down.mod.edit.inline.Config
M.config = {}

return M
