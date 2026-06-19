--- Builtin find module
--- @class down.mod.find.builtin.Builtin: down.Mod
local Builtin = require("down.mod").new("find.builtin")

--- @class down.mod.find.builtin.Config: down.mod.Config
Builtin.config = {}

Builtin.setup = function()
  return { loaded = true }
end

Builtin.pick = {

}

return Builtin
