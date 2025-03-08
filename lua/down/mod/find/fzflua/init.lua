--- Fzflua find module
---
--- @class down.mod.find.fzflua.Fzflua: down.Mod
local Fzflua = require("down.mod").new("find.fzflua")

--- @class down.mod.find.builtin.Config: down.mod.Config
Fzflua.config = {}

Fzflua.setup = function()
  return {
    dependencies = {},
    loaded = true,
  }
end

Fzflua.load = function() end

return Fzflua
