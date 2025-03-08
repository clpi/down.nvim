local log = require("down.util.log")
local mod = require("down.mod")

local P = mod.new("edit.parse")

P.setup = function()
  return {
    loaded = true,
    dependencies = {
      "data",
      "tool.treesitter",
    },
  }
end

P.load = function() end

---@class down.mod.parse.Config
P.config = {}

return P
