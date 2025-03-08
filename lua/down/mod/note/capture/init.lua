local mod = require 'down.mod'
local log = require 'down.util.log'

---@type down.Mod
local Capture = mod.new 'note.capture'

---@return down.mod.Setup
Capture.setup = function()
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
Capture.config = {}

---@class down.mod.note.capture.Events
Capture.events = {}

---@class down.mod.note.capture.Subscribed
Capture.handle = {
  cmd = {
    ['capture'] = true,
  },
}

return Capture
