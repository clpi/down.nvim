local picker = require("down.mod.find.telescope.picker")

--- Telescope module
---@class down.mod.find.telescope.Telescopeelescope: down.Mod
local Telescope = require("down.mod").new("find.telescope")

local ok, tel = pcall(require, "telescope")

---@param n down.mod.find.Picker
Telescope.picker = function(n)
  local p = require("down.mod.find.telescope.picker")
  if n then
    return p.down[n]
  end
  return p
end

---@return down.mod.Setup
Telescope.setup = function()
  ---@type down.mod.Setup
  return {
    loaded = ok,
    dependencies = {},
  }
end

Telescope.load = function()
  Telescope.picker = picker
  tel.register_extension({
    exports = Telescope.picker.down,
  })
  tel.load_extension("down")
end

---@class down.mod.find.telescope.Config: down.mod.Config
Telescope.config = {
  enabled = true,
}

Telescope.data = {}

return Telescope
