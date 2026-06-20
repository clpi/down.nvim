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
  "template",
  "find",
  "lsp",
  "lsp.completion",
  "tag",
  "mcp",
  "data.knowledge",
  "data.props",
  "data.database",
  "data.semantic",
  "ai",
  "ai.chat",
  "ai.gen",
  "automate",
  "edit.inline",
  "code",
  "footnote",
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

  -- Auto-install down CLI binary if not present
  Down:ensure_cli ()

  -- Load data module first so persistent data is available for workspace
  self.mod.load_mod ("data")

  -- Load workspace first with user config
  local ws_config = self.config.user.workspace
    or self.config.user.workspaces
    or {}
  self.mod.load_mod ("workspace", ws_config)

  -- Load default modules
  for _, name in ipairs (Down.default_mods) do
    if not self.mod.is_loaded (name) then
      local mod_config = self.config.user[name]
      if type (mod_config) == "table" then
        self.mod.load_mod (name, mod_config)
      elseif mod_config ~= false then
        self.mod.load_mod (name)
      end
    end
  end

  -- Load user-specified modules
  for name, usermod in pairs (self.config.user) do
    if self.mod.check_id (name) and not self.mod.is_loaded (name) then
      if type (usermod) == "table" then
        self.mod.load_mod (name, usermod)
      elseif usermod ~= false then
        self.mod.load_mod (name)
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
      self.mod.load_mod (
        "integration.cmp",
        type (cmp_config) == "table" and cmp_config or {}
      )
    end
  end

  -- blink.cmp integration
  local has_blink = pcall (require, "blink.cmp")
  if has_blink and not self.mod.is_loaded ("integration.blink") then
    local blink_config = self.config.user["integration.blink"]
    if blink_config ~= false then
      self.mod.load_mod (
        "integration.blink",
        type (blink_config) == "table" and blink_config or {}
      )
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

--- Ensure the down CLI binary is installed at first plugin load
function Down:ensure_cli ()
  local bin_dir = vim.fn.stdpath ("data") .. "/down/bin"
  local bin_path = bin_dir .. "/down"
  if vim.fn.executable (bin_path) == 1 then
    return
  end
  if vim.fn.executable ("down") == 1 then
    return
  end
  vim.fn.mkdir (bin_dir, "p")

  local ext_down = nil
  local runtime = vim.api.nvim_get_runtime_file ("lua/down.lua", false)
  if runtime and runtime[1] then
    ext_down =
      vim.fs.joinpath (vim.fn.fnamemodify (runtime[1], ":p:h:h"), "ext", "down")
  end
  if
    ext_down
    and vim.fn.isdirectory (ext_down) == 1
    and vim.fn.executable ("go") == 1
  then
    pcall (
      vim.fn.jobstart,
      { "go", "build", "-o", bin_path, "." },
      { cwd = ext_down }
    )
  end
end

return setmetatable (Down, {
  __call = function (_, user, ...)
    Down.setup (user, ...)
  end,
})
