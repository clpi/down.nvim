---@author clpi
---@file down.nvim 0.1.0
---@license MIT
---@package down.nvim
---@brief neovim note-taking plugin with the
---@brief comfort of mmarkdown and the power of org

---@class down.down
local down = {
  ---@type down.config.Config
  config = require('down.config'),
  mod = require('down.mod'),
  event = require('down.event'),
  util = require('down.util'),
  log = require('down.util.log'),
  trouble = require('trouble.providers.down'),
  telescope = require('telescope._extensions.down'),
}

--- Load the user configuration, and load into config
--- defined modules specifieed and workspaces
--- @param user down.mod.Config user config to load
--- @param ... string The arguments to pass into an optional user hook
function down.setup(user, ...)
  down.util.log.trace('Setting up down')
  vim.print(vim.inspect(user))
  down.config:setup(user, ...)
  down.start(user, ...)
end

function down.start(user, ...)
  down.util.log.trace('Setting up down')
  down.mod.load_mod('workspace', down.config.user.workspace or down.config.user.workspaces or {})
  down.config:load(user)
  -- for name, usermod in pairs(down.config.user) do
  --   if require('down.util.mod').check_id(name) and type(usermod) == 'table' then
  --     if down.mod.load_mod(name, usermod) == nil then
  --       vim.print('Failed to load mod: ' .. name)
  --     end
  --   end
  --   if type(usermod) == 'table' then
  --     elseif name == 'workspaces' then
  --     elseif name == 'workspace' then
  --     elseif down.mod.load_mod(name, usermod) == nil then
  --     end
  --   else
  --     down.config[name] = usermod
  --   end
  -- end
  down.config:post_load()
end

function down:post_load()
  -- vim.api.nvim_create_autocmd('BufEnter',
  --   {
  --     callback = function()
  --       for _, l in pairs(down.mod.mods) do
  --         down.mod.load_maps(l)
  --         down.mod.load_opts(l)
  --       end
  --     end,
  --     pattern = "markdown",
  --   }
  -- )
  -- self:post_load()
  self.config:post_load()
  for _, l in pairs(self.mod.mods) do
    self.event.load_cb(l)
    l.post_load()
  end
  self:broadcast('started')
end

---@param e string
---@param ... any
function down:broadcast(e, ...)
  local ev = self.event.define('down', e or 'started') ---@type down.Event
  self.event.broadcast_to(ev, down.mod.mods)
end

--- Test all modules loaded
function down.test()
  down.config:test()
  for m, d in pairs(down.mod.mods) do
    print('Testing mod: ' .. m)
    d.test()
  end
end

return setmetatable(down, {
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
