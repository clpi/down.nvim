--- Mini find module
---
--- @class down.mod.find.fzflua.Mini: down.Mod
local Mini = require("down.mod").new("find.mini")

--- @class down.mod.find.builtin.Config: down.mod.Config
Mini.config = {}

Mini.setup = function()
  return {
    dependencies = {},
    loaded = true,
  }
end

Mini.load = function() end

return Mini
