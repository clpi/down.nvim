-- TODO: do-over

--- @brief First, import the module class for type suggestions and checking
local mod = require "down.mod"

---@brief Your first module will likely be a root (parentless) module.
---       Typically, a `.` separates the name in the module name only if
---       it separates the parent module name (left) from the child (right).
---       However, you may choose to quickly
---@type word.Mod
local M = mod.create("user.mod", {
  --- @brief submodules
  ---         child directories containing
  ---         modules to load in tandem, relative
  ---         to this (parent) module.
  --- "subexample",
  --- "pre_example",
  --- ...
})

M.setup = function()
  return {
    requires = {
      ---@brief dep modules
      ---         modules from builtin or custom
      ---         modules that can be loaded in (same as
      ---         if calling `require 'module'`) as a dependency
      ---         for the module.
      --- "ui.popup",
      --- "edit.link",
      --- "integration.treesitter",
      --- ...
    },
    loaded = true,
  }
end

---@class (exact) example.Config
M.config = {
  --- @brief module config
  ---          the public facing config for this module that can be
  ---          set by the user from its default values here.
  --- ...
}

---@class example.Data
M. = {
  --- @brief module data
  ---          the home of the module's internal data and methods
  ---          TODO: split up concerns
  --- ...
}

M.load = function()
  --- @brief module load
  ---          a set of functions to run whenever the
  ---          module is fist loaded upon startup.
  ---          TODO: maybe just merge in with setup()
  --- ...
end

return M
