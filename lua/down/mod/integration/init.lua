local mod = require("down.mod")
local util = require("down.util")
local log = util.log

---TODO: imelement
---@class down.mod.Tool: down.Mod
local E = mod.new("integration")

--TODO: implement config to initialize sub integrations depending on user confiE

---@class down.mod.integration.Config
E.config = {
  ---@brief List of integrations to disable (relative to the integration dir)
  disabled = {},
  ---@brief List of integrations to enable (relative to the integration dir)
  enabled = {
    "telescope",
  },
}

---@param ext string
---@return string
E.get = function(ext) end

---TODO: implement
---Returns either a table of the loaded dependencies or nil of one is unsuccessful
---@return table<string, any>|nil: the loaded dependency package
---@param ext string: the integration module to check
E.deps = function(ext)
  return nil
end

---@return boolean, nil|nil
---@param ext string
E.has = function(ext)
  return pcall(require, ext)
end

--- Generic setup function for integration submodules
--- @param ext string: the integration to setup
--- @param req table<string>: the modules dep by the integration module
--- @return down.mod.Setup
E.generic_setup = function(ext, req)
  local ok, e = E.has(ext)
  if ok then
    return {
      dependencies = req,
      loaded = true,
    }
  else
    return {
      loaded = false,
    }
  end
end

E.setup = function()
  local enabled = {}
  return {
    loaded = true,
    dependencies = enabled,
  }
end

return E
