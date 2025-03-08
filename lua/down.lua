---@package down.nvim
---@brief v0.1.2-alpha
---@author Chris Pecunies <clp@clp.is>
---@repository https://github.com/clpi/down.nvim.git
---@homepage https://down.cli.st
---@license MIT
---@tags markdown, org-mode, note-taking, knowledge-management, developer-tools, productivity
---
---@brief The Neovim plugin for the *down* _markdown_ developer-focused
---@brief note-taking and knowledge management environment, offering the comfort familiarity, and compatibility of a traditional markdown note-taking environment with the power of org-mode.

--- The main entry point for the down plugin
---@class down.Down
Down = {
  --- The configuration for the plugin
  config = require("down.config"),
  --- The module logic for the plugin
  mod = require("down.mod"),
  --- The event logic for the plugin
  event = require("down.event"),
  --- The utility logic for the plugin
  util = require("down.util"),
  --- The log logic for the plugin
  log = require("down.util.log"),
}

--- Load the user configuration, and load into config
--- defined modules specifieed and workspaces
--- @param user down.config.User user config to load
--- @param ... string The arguments to pass into an optional user hook
Down.setup = function(user, ...)
  Down.util.log.trace("Setting up down")
  Down.config:setup(user, ...)
  Down:start()
end

--- *Start* the ^down.nvim^ plugin
--- Load the workspace and user modules
function Down:start()
  self.util.log.trace("Setting up down")
  self.mod.load_mod(
    "workspace",
    self.config.user.workspace or self.config.user.workspaces
  )
  for name, usermod in pairs(self.config.user) do
    if self.mod.check_id(name) then
      self.mod.load_mod(name, usermod)
    end
  end
  self:after()
end

--- After the plugin has started
function Down:after()
  self.config:after()
  for _, l in pairs(self.mod.mods) do
    self.event.load_callback(l)
    l.after()
  end
  self:broadcast("started")
end

--- Broadcast the message `e` or the 'started' event to all modules
---@param e string
---@param ... any
function Down:broadcast(e, ...)
  local ev = self.event.define("down", e or "started") ---@type down.Event
  self.event.broadcast_to(ev, Down.mod.mods)
end

--- Test all modules loaded
function Down.test()
  Down.config:test()
  for m, d in pairs(Down.mod.mods) do
    Down.util.log.trace("Testing mod: " .. m)
    Down.util.log.trace("Result: " .. d.test())
  end
end

return setmetatable(Down, {
  __call = function(down, user, ...)
    Down.setup(user, ...)
  end,
  -- __call = function(down, user, ...)
  --   down.setup(user, ...)
  -- end,
  -- __index = function(self, key)
  --   return down.mod.mods[key]
  -- end,
  -- __newindex = function(self, key, val)
  --   down.mod.mods[key] = val
  -- end,
})
