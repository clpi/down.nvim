---@brief v0.1.2-alpha
---@author Chris Pecunies <clp@clp.is>
---@repository https://github.com/clpi/down.nvim.git
---@homepage https://down.cli.st
---@license MIT
---@tags markdown, org-mode, note-taking, knowledge-management, developer-integrations, productivity
---
---@brief The Neovim plugin for the *down* _markdown_ developer-focused
---@brief note-taking and knowledge management environment, offering the comfort familiarity, and compatibility of a traditional markdown note-taking environment with the power of org-mode.

--- The main entry point for the down plugin
---@class down.Down
local Down = {
  --- The configuration for the plugin
  config = require ("down.config"),
  --- The module logic for the plugin
  mod = require ("down.mod"),
  --- The event logic for the plugin
  event = require ("down.event"),
  --- The utility logic for the plugin
  util = require ("down.util"),
  --- The log logic for the plugin
  log = require ("down.log"),
}

--- Default modules that are always loaded
Down.default_mods = {
  "cmd",
  "workspace",
  "data",
  "note",
  "find",
  "lsp",
  "lsp.completion",
  "tag",
  "mcp",
  "data.knowledge",
}

--- Load the user configuration, and load into config
--- defined modules specifieed and workspaces
--- @param user_config down.config.User user config to load
--- @param ... string The arguments to pass into an optional user hook
Down.setup = function (user_config, ...)
  Down.log.trace ("Setting up down")
  Down.config:setup (user_config, ...)
  Down:start ()
end

--- *Start* the ^down.nvim^ plugin
--- Load the workspace and user modules
function Down:start ()
  self.log.trace ("Starting down")

  -- Load workspace first with user config
  local ws_config = self.config.user.workspace
    or self.config.user.workspaces
    or {}
  self.mod.load_mod ("workspace", ws_config)

  -- Load default modules
  for _, name in ipairs (Down.default_mods) do
    if not self.mod.is_loaded (name) then
      local mod_config = self.config.user[name]
      local ok, err
      if type (mod_config) == "table" then
        ok, err = pcall (self.mod.load_mod, name, mod_config)
      elseif mod_config ~= false then
        ok, err = pcall (self.mod.load_mod, name)
      else
        ok = true
      end
      if not ok then
        self.log.warn ("Failed to load default module '" .. name .. "': " .. tostring (err))
      end
    end
  end

  -- Load user-specified modules
  for name, usermod in pairs (self.config.user) do
    if self.mod.check_id (name) and not self.mod.is_loaded (name) then
      local ok, err
      if type (usermod) == "table" then
        ok, err = pcall (self.mod.load_mod, name, usermod)
      elseif usermod ~= false then
        ok, err = pcall (self.mod.load_mod, name)
      else
        ok = true
      end
      if not ok then
        self.log.warn ("Failed to load module '" .. name .. "': " .. tostring (err))
      end
    end
  end

  -- Auto-load completion integrations based on available plugins
  self:load_integrations ()

  self:after ()
end

--- Automatically load integration modules for installed completion frameworks
function Down:load_integrations ()
  -- nvim-cmp integration
  local has_cmp = pcall (require, "cmp")
  if has_cmp and not self.mod.is_loaded ("integration.cmp") then
    local cmp_config = self.config.user["integration.cmp"]
    if cmp_config ~= false then
      local ok, err = pcall (self.mod.load_mod, "integration.cmp", type (cmp_config) == "table" and cmp_config or {})
      if not ok then
        self.log.warn ("Failed to load integration.cmp: " .. tostring (err))
      end
    end
  end

  -- blink.cmp integration
  local has_blink = pcall (require, "blink.cmp")
  if has_blink and not self.mod.is_loaded ("integration.blink") then
    local blink_config = self.config.user["integration.blink"]
    if blink_config ~= false then
      local ok, err = pcall (self.mod.load_mod, "integration.blink", type (blink_config) == "table" and blink_config or {})
      if not ok then
        self.log.warn ("Failed to load integration.blink: " .. tostring (err))
      end
    end
  end

  -- Telescope integration
  local has_telescope = pcall (require, "telescope")
  if has_telescope and not self.mod.is_loaded ("integration.telescope") then
    local tel_config = self.config.user["integration.telescope"]
    if tel_config ~= false then
      local ok, err = pcall (self.mod.load_mod, "integration.telescope", type (tel_config) == "table" and tel_config or {})
      if not ok then
        self.log.warn ("Failed to load integration.telescope: " .. tostring (err))
      end
    end
  end
end

--- After the plugin has started
function Down:after ()
  self.config:after ()
  for _, l in pairs (self.mod.mods) do
    self.event.load_callback (l)
    if l.after then
      l.after ()
    end
  end
  self:broadcast ("started")
end

--- Broadcast the message `e` or the 'started' event to all modules
---@param e string
---@param ... any
function Down:broadcast (e, ...)
  ---@type down.Event
  local ev = self.event.define ("down", e or "started")
  for _, m in pairs (Down.mod.mods) do
    if m.handle and m.handle["down"] and m.handle["down"][e] then
      m.handle["down"][e] (ev)
    end
  end
end

--- Test all modules loaded
function Down:test ()
  Down.config:test ()
  for m, d in pairs (Down.mod.mods) do
    Down.log.trace ("Testing mod: " .. m)
    if d.test then
      Down.log.trace ("Result: " .. tostring (d.test ()))
    end
  end
end

return setmetatable (Down, {
  __call = function (_, user, ...)
    Down.setup (user, ...)
  end,
})
