--- Snacks find module
---
--- @class down.mod.find.fzflua.Snacks: down.Mod
local Snacks = require("down.mod").new("find.mini")

--- @class down.mod.find.builtin.Config: down.mod.Config
Snacks.config = {}

Snacks.setup = function()
  return {
    dependencies = {},
    loaded = true,
  }
end

Snacks.load = function() end

return Snacks
