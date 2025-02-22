---@class down.mod.find.telescope.Telescope: down.Mod
local T = require("down.mod").new("find.telescope")

local ok, tel = pcall(require, "telescope")

---@param n down.mod.find.Picker
T.picker = function(n)
  local p = require("down.mod.find.telescope.picker")
  if n then
    return p.down[n]
  end
  return p
end

---@return down.mod.Setup
T.setup = function()
  ---@type down.mod.Setup
  return {
    loaded = ok,
    dependencies = {},
  }
end

T.load = function()
  T.picker = { down = require("down.mod.find.telescope.picker") }
  tel.register_extension({
    exports = T.picker.down,
  })
  tel.load_extension("down")
end

---@class down.mod.find.telescope.Config: down.mod.Config
T.config = {
  enabled = true,
}

T.data = {}

return T
