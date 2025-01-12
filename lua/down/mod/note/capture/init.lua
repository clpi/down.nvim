local mod = require 'down.mod'
local log = require 'down.util.log'

---@type down.Mod
local M = mod.new 'note.capture'

---@return down.mod.Setup
M.setup = function()
  ---@type down.mod.Setup
  return {
    loaded = true,
    dependencies = {
      'cmd',
      'ui',
      'ui.popup',
      'workspace',
    },
  }
end

---@class down.mod.note.capture.Config
M.config = {}

---@class down.mod.note.capture.Events
M.events = {}

---@class down.mod.note.capture.Subscribed
M.handle = {
  cmd = {
    ['capture'] = true,
  },
}

return M
