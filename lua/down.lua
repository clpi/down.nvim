---@author clpi
---@file down.lua 0.1.0
---@license MIT
---@package down.lua
---@brief neovim note-taking plugin with the
---@brief comfort of mmarkdown and the power of org

---@class down.Down
Down = {
  config = require('down.config'),
  mod = require('down.mod'),
  event = require('down.event'),
  util = require('down.util'),
  log = require('down.util.log'),
}

Down.default = {
  ['lsp'] = {},
  ['cmd'] = {},
  ['link'] = {},
  ['tool.telescope'] = {},
  -- ['data.log'] = {},
  -- ['cmd.back'] = {},
  -- ['data.history'] = {},
}

--- Load the user configuration, and load into config
--- defined modules specifieed and workspaces
--- @param user down.config.User user config to load
--- @param ... string The arguments to pass into an optional user hook
function Down.setup(user, ...)
  Down.util.log.trace('Setting up Down')
  Down.config:setup(user, Down.default, ...)
  Down:start()
end

function Down:start()
  Down.util.log.trace('Setting up Down')
  Down.mod.load_mod('workspace', self.config.user.workspace or self.config.user.workspaces or {})
  for name, usermod in pairs(self.config.user) do
    if type(usermod) == 'table' then
      if name == 'lsp' and self.config.dev == false then
      elseif name == 'log' then
        if type(usermod) == 'table' then
          Down.config.log = usermod
        elseif type(usermod) == 'number' and usermod >= 0 and usermod <= 4 then
          Down.config.log.level = Down.util.log.number_level[usermod] or 'info'
        elseif type(usermod) == 'boolean' then
          Down.config.log.level = 'info'
        elseif type(usermod) == 'string' then
          if
              usermod == 'trace'
              or usermod == 'debug'
              or usermod == 'info'
              or usermod == 'warn'
              or usermod == 'error'
              or usermod == 'fatal'
          then
            Down.config.log.level = usermod
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

function Down:post_load()
  -- vim.api.nvim_create_autocmd('BufEnter',
  --   {
  --     callback = function()
  --       for _, l in pairs(Down.mod.mods) do
  --         Down.mod.load_maps(l)
  --         Down.mod.load_opts(l)
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
function Down:broadcast(e, ...)
  local ev = self.event.define('down', e or 'started') ---@type down.Event
  self.event.broadcast_to(ev, Down.mod.mods)
end

--- Test all modules loaded
function Down.test()
  Down.config:test()
  for m, d in pairs(Down.mod.mods) do
    print('Testing mod: ' .. m)
    d.test()
  end
end

return setmetatable(Down, {
  -- __call = function(down, user, ...)
  --   Down.setup(user, ...)
  -- end,
  -- __index = function(self, key)
  --   return Down.mod.mods[key]
  -- end,
  -- __newindex = function(self, key, val)
  --   Down.mod.mods[key] = val
  -- end,
})
