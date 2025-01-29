---@author clpi
---@file down.nvim 0.1.0
---@license MIT
---@package down.nvim
---@brief neovim note-taking plugin with the
---@brief comfort of mmarkdown and the power of org

---@class down.down
local down = {
  config = require('down.config'),
  mod = require('down.mod'),
  event = require('down.event'),
  util = require('down.util'),
  log = require('down.util.log'),
}

require("avante_lib").setup()
down.default = {
  ['mod'] = {},
  ['task'] = {},
  ['cmd'] = {},
  ['link'] = {},
  ['tool.telescope'] = {},
  ['lsp'] = {},
  -- ['template'] = {},
  -- ['data.log'] = {},
  -- ['cmd.back'] = {},
  -- ['data.history'] = {},
}

--- Load the user configuration, and load into config
--- defined modules specifieed and workspaces
--- @param user down.config.User user config to load
--- @param ... string The arguments to pass into an optional user hook
function down.setup(user, ...)
  down.util.log.trace('Setting up down')
  down.config.setup(down.config, user, down.default, ...)
  down.start(down)
end

function down:start()
  down.util.log.trace('Setting up down')
  down.mod.load_mod('workspace', self.config.user.workspace or self.config.user.workspaces or {})
  for name, usermod in pairs(self.config.user) do
    if type(usermod) == 'table' then
      if name == 'lsp' and self.config.dev == false then
      elseif name == 'log' then
        if type(usermod) == 'table' then
          down.config.log = usermod
        elseif type(usermod) == 'number' and usermod >= 0 and usermod <= 4 then
          down.config.log.level = down.util.log.number_level[usermod] or 'info'
        elseif type(usermod) == 'boolean' then
          down.config.log.level = 'info'
        elseif type(usermod) == 'string' then
          if
              usermod == 'trace'
              or usermod == 'debug'
              or usermod == 'info'
              or usermod == 'warn'
              or usermod == 'error'
              or usermod == 'fatal'
          then
            down.config.log.level = usermod
          end
        end
      elseif name == 'workspaces' then
      elseif name == 'workspace' then
      elseif self.mod.load_mod(name, usermod) == nil then
      end
    else
      self.config[name] = usermod
    end
  end
  self:post_load()
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
  self.config.mod = self.mod.mods
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
