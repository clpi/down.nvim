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
  config = require("down.config"),
  --- The module logic for the plugin
  mod = require("down.mod"),
  --- The event logic for the plugin
  event = require("down.event"),
  --- The utility logic for the plugin
  util = require("down.util"),
  --- The log logic for the plugin
  log = require("down.log"),
}

--- Load the user configuration, and load into config
--- defined modules specifieed and workspaces
--- @param user_config down.config.User user config to load
--- @param ... string The arguments to pass into an optional user hook
function Down:setup(user_config, ...)
  Down.log.trace("Setting up down")
  Down.config:setup(user_config, ...)
  Down:start()
end

--- *Start* the ^down.nvim^ plugin
--- Load the workspace and user modules
function Down:start()
  Down.log.trace("Setting up down")
  Down.mod.load_mod(
    "workspace",
    Down.config.user.workspace or Down.config.user.workspaces
  )
  for name, usermod in pairs(Down.config.user) do
    if Down.mod.check_id(name) then
      Down.mod.load_mod(name, usermod)
    end
  end
  Down:after()
end

--- After the plugin has started
function Down:after()
  Down.config:after()
  for _, l in pairs(Down.mod.mods) do
    Down.event.load_callback(l)
    l.after()
  end
  Down:broadcast("started")
end

--- Broadcast the message `e` or the 'started' event to all modules
---@param e string
---@param ... any
function Down:broadcast(e, ...)
  local ev = Down.event.define("down", e or "started") ---@type down.Event
  Down.event.broadcast_to(ev, Down.mod.mods)
end

--- Test all modules loaded
function Down:test()
  Down.config:test()
  for m, d in pairs(Down.mod.mods) do
    Down.log.trace("Testing mod: " .. m)
    Down.log.trace("Result: " .. d.test())
  end
end

return setmetatable(Down, {
  __call = function(down, user, ...)
    Down.setup(user, ...)
  end,
  -- __index = function(Down, key)
  --   return down.mod.mods[key]
  -- end,
  -- __newindex = function(Down, key, val)
  --   down.mod.mods[key] = val
  -- end,
})
