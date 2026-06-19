local log = require("down.log")
local mod = require("down.mod")

local Parse = mod.new("edit.parse")
Parse.dep = { "data", "integration.treesitter" }

Parse.setup = function()
  return {
    loaded = true,
  }
end

---@class down.mod.parse.Config
Parse.config = {}

return Parse
