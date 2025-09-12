local log = require("down.util.log")
local mod = require("down.mod")

local Parse = mod.new("edit.parse")

Parse.setup = function()
  return {
    loaded = true,
    dependencies = {
      "data",
      "integration.treesitter",
    },
  }
end

Parse.load = function() end

---@class down.mod.parse.Config
Parse.config = {}

return Parse
