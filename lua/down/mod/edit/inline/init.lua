local mod = require 'down.mod'

---@class down.mod.edit.Inline: down.Inlineod
local Inline = mod.new 'edit.inline'

Inline.setup = function()
  return {
    loaded = true,
  }
end

---@class down.mod.edit.inline.Config
Inline.config = {}

return Inline
