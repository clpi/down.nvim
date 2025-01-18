local Event = require 'down.event'
local util = require 'down.util'
local log = require('down.util.log')

--- @!TODO : Change to body access where appropriate and now available to avoid complex config for end user
---   1. Firsr try with  Ms, then workspace
---
--- @TODO: Merge Module. with Module, Module.config as subfield for all modules
---        which have class then of down.mod.[Mod] as M
---
---
--- TODO: Make Mod.subscribed be [string]: function() instead of [string]: boolean
---       and eliminate Mod.handler(e)

---@class down.Mod
local Mod = {
  setup = function()
    return {
      loaded = true,
      replaces = {},
      merge = false,
      dependencies = {},
    }
  end,
  load = function()
    -- print 'default load n'
  end,
  post_load = function()
    -- print('postload' .. n)
  end,
  opts = {},
  maps = {},
  commands = {},
  handle = {},
  id = '',
  namespace = vim.api.nvim_create_namespace('down.mod'),
  config = {},
  events = {},
  dep = {},
  import = {},
  tests = {},
}

Mod.metatable = {
  ---@type metatable
  handle = {
    __index = function(self, k)
      if type(k) == 'table' then
        if k.split then
          return self[k.split[1]][k.split[2]]
        end
        return self[k[1]][k[2]]
      elseif type(k) == 'string' then
        local ks = string.split(k, '%.')
        if #ks == 1 then
          return self[ks[1]]
        end
        return self[ks[1]][ks[2]]
      end
      return self[k]
    end,
    __newindex = function(self, k, v)
      self[k] = v
    end,
    __call = function(self, e, ...)
      if e then
        if self[e] and type(self[e]) == 'function' then
          return self[e](e)
        end
        return self[e](e)
      end
      return self(e)
    end,
  },
  ---@type metatable
  mod = {
    __index = function(self, k)
      return self.dep[k]
    end,
    __eq = function(m1, m2)
      return m1.id == m2.id
    end,
  },
}

Mod.mods = {}

Mod.default = {
  mods = {
    'tool.telescope',
    -- 'lsp',
    'note',
    'workspace',
    -- 'data.log',
    -- 'template',
  },
  ---@type fun():down.mod.Setup
  setup = function()
    return {
      loaded = true,
      replaces = {},
      merge = false,
      dependencies = {},
    }
  end,
  ---@return down.Mod
  mod = function(n)
    ---@type down.Mod
    return setmetatable({
      setup = Mod.setup,
      commands = {},
      load = function()
        -- print 'default load n'
      end,
      post_load = function()
        -- print('postload' .. n)
      end,
      opts = {},
      maps = {},
      -- handle = setmetatable({}, Mod..metatable.handle),
      handle = {},
      id = n,
      namespace = vim.api.nvim_create_namespace('down.mod.' .. n),
      config = {},
      events = {},
      dep = {},
      import = {},
      tests = {},
    }, Mod.metatable)
  end,
}

--- @param nm string
--- @param im? string[]
Mod.new = function(nm, im)
  local n = Mod.default.mod(nm)
  if im then
    for _, imp in ipairs(im) do
      local fp = table.concat({ nm, imp }, '.')
      if not Mod.load_mod(fp) then
        log.error("Unable to load import '" .. fp .. "'! An error  (see traceback below):")
        assert(false)
      end
      n.import[fp] = Mod.mods[fp]
    end
  end
  return n
end

--- @param mod string
---@return nil
Mod.delete = function(mod)
  Mod.mods[mod] = nil
  return nil
end

--- @param m down.Mod.Mod The actual mod to load.
--- @return down.Mod|nil # Whether the mod successfully loaded.
Mod.load_mod_from_table = function(m, cfg)
  if Mod.mods[m.id] ~= nil then
    return Mod.mods[m.id]
  end
  local mod_load = m.setup and m.setup() or Mod.default.setup()
  ---@type down.Mod
  local mod_to_replace
  if mod_load.replaces and mod_load.replaces ~= '' then
    mod_to_replace = vim.deepcopy(Mod.mods[mod_load.replaces])
  end
  Mod.mods[m.id] = m
  if mod_load.dependencies and vim.tbl_count(mod_load.dependencies) then
    for _, req in pairs(mod_load.dependencies) do
      if not Mod.is_loaded(req) then
        if not Mod.load_mod(req) then
          return Mod.delete(m.id)
        end
      end
      m.dep[req] = Mod.mods[req]
    end
  end
  if mod_to_replace then
    m.id = mod_to_replace.id
    if mod_to_replace.replaced then
      return Mod.delete(m.id)
    end
    if mod_load.merge then
      m = vim.tbl_deep_extend('force', m, mod_to_replace)
    end
    m.replaced = true
  end
  Mod.mod_load(m)
  return Mod.mods[m.id]
end

--- @param n string
--- @return down.config.Mod?
function Mod.check_mod(n)
  local modl = require('down.mod.' .. n)
  if not modl then
    log.error('Mod.load_mod: could not load mod ' .. n)
    return nil
  elseif modl == true then
    log.error('did not return valid mod: ' .. n)
    return nil
  end
  return modl
end

--- @param modn string A path to a mod on disk. A path in down is '.', not '/'.
--- @param cfg table? A config that reflects the structure of `down.config.user.setup["mod.id"].config`.
--- @return down.Mod|nil # Whether the mod was successfully loaded.
function Mod.load_mod(modn, cfg)
  if Mod.mods[modn] then
    if cfg ~= nil then
      Mod.mods[modn].config = util.extend(cfg or {}, Mod.mods[modn].config)
    end
    return Mod.mods[modn]
  end
  local modl = Mod.check_mod(modn)
  if not modl then
    return nil
  end
  if cfg and not vim.tbl_isempty(cfg) then
    modl.config = util.extend(modl.config, cfg)
  end
  return Mod.load_mod_from_table(modl)
end

--- Has the same principle of operation as load_mod_from_table(), except it then sets up the parent mod's "dep" table, allowing the parent to access the child as if it were a dependency.
--- @param md down.Mod A valid table as returned by mod.new()
--- @param parent_mod string|down.Mod If a string, then the parent is searched for in the loaded mod. If a table, then the mod is treated as a valid mod as returned by mod.new()
function Mod.load_mod_as_dependency_from_table(md, parent_mod)
  if Mod.load_mod_from_table(md) then
    if type(parent_mod) == 'string' then
      Mod.mods[parent_mod].dep[md.id] = md
    elseif type(parent_mod) == 'table' then
      parent_mod.dep[md.id] = md
    end
  end
end

--- Normally loads a mod, but then sets up the parent mod's "dep" table, allowing the parent mod to access the child as if it were a dependency.
--- @param modn string A path to a mod on disk. A path  in down is '.', not '/'
--- @param parent_mod string The name of the parent mod. This is the mod which the dependency will be attached to.
--- @param cfg? table A config that reflects the structure of down.config.user.setup["mod.id"].config
function Mod.load_mod_as_dependency(modn, parent_mod, cfg)
  if Mod.load_mod(modn, cfg) and Mod.is_loaded(parent_mod) then
    Mod.mods[parent_mod].dep[modn] = Mod.mod_config(modn)
  end
end

--- Returns the mod.config table if the mod is loaded
--- @param modn string The name of the mod to retrieve (mod must be loaded)
--- @return table?
function Mod.mod_config(modn)
  if not Mod.is_loaded(modn) then
    log.trace('Attempt to get mod config with name' .. modn .. 'failed - mod is not loaded.')
    return
  end
  return Mod.mods[modn].config
end

--- Retrieves the public API exposed by the mod.
--- @generic T
--- @param modn `T` The name of the mod to retrieve.
--- @return T?
function Mod.get_mod(modn)
  if not Mod.is_loaded(modn) then
    log.trace('Attempt to get mod with name' .. modn .. 'failed - mod is not loaded.')
    return
  end
  return Mod.mods[modn]
end

--- Returns true if mod with name modn is loaded, false otherwise
--- @param modn string The name of an arbitrary mod
--- @return down.Mod|nil
function Mod.is_loaded(modn)
  if Mod.mods[modn] ~= nil then
    return Mod.mods[modn]
  end
  return nil
end

--- Executes `callback` once `mod` is a valid and loaded mod, else the callback gets instantly executed.
--- @param modn string The name of the mod to listen for.
--- @param cb fun(mod_public_table: table)
function Mod.await(modn, cb)
  if Mod.is_loaded(modn) then
    cb(assert(Mod.get_mod(modn)))
  else
    Event.callback('mod_loaded', function(_, m)
      cb(m)
    end, function(e)
      return e.body.id == modn
    end)
  end
end

---@field k table|function
---@field kt? function
function Mod.load_kind(mk, kt)
  if type(mk) == 'function' then
    mk()
  elseif type(mk) == 'nil' then
    return
  elseif type(mk) == 'table' then
    for k, v in pairs(mk) do
      kt(k, v)
    end
  end
end

---@param m down.Mod
function Mod.load_opts(m)
  Mod.load_kind(m.opts, function(k, v)
    vim.bo[k] = v
  end)
end

---@param m down.Mod
function Mod.load_maps(m)
  Mod.load_kind(m.maps, function(_, v)
    local opts = {
      noremap = true,
      nowait = true,
      silent = true,
    }
    if type(v[4]) == 'string' then
      opts.desc = v[4]
    elseif type(v[4]) == 'table' then
      opts = v[4]
    elseif type(v[4]) == 'nil' then
      opts.desc = v[3] or ''
    end
    vim.keymap.set(v[1] or 'n', v[2], v[3], opts)
  end)
end

---@param m down.Mod
function Mod.mod_load(m)
  Mod.load_maps(m)
  Mod.load_opts(m)
  Event.load_cb(m)
  if m.load then
    m.load()
  end
end

Mod.get = function(m)
  local ok, pc = pcall(require, 'down.mod.' .. m)
  if ok then
    return pc
  else
    log.error('Mod.get: could not load mod ' .. 'down.mod.' .. m)
    return nil
  end
end
--- @param ms? table<any, string> list of modules to load
--- @return table<integer, down.Mod>
Mod.modules = function(ms)
  local modmap = {}
  for _, module in ipairs(ms or Mod.default.mods) do
    modmap[module] = Mod.get(module)
  end
  return modmap
end

---@param m down.Mod
Mod.test = function(m)
  log.info('Mod.test: Performing tests for ', m.id, ': ')
  if m.tests then
    for tn, test in m.tests do
      log.info('Mod.test: Running test ', tn, ' for ', m.id, ': ', test(m))
    end
  end
end

---@param cmds down.Commands
---@return boolean
Mod.handle_cmd = function(self, e, cmd, cmds, ...)
  log.trace('Mod.handle_cmd: Handling cmd ', cmd, ' for mod ', self.id)
  if not cmds or type(cmds) ~= 'table' or not cmds[cmd] then
    return false
  end
  if cmds.enabled ~= nil and cmds.enabled == false then return false end
  local cc = cmds[cmd]
  if cc.enabled ~= nil and cc.enabled == false then return false end
  if cc.name and cc.name == cmd and cc.callback then
    if not self.handle then
      self.handle = {}
    end
    if not self.handle['cmd'] then
      self.handle['cmd'] = {}
    end
    if not self.handle['cmd'][cmd] then
      self.handle['cmd'][cmd] = cc.callback
    end
    cc.callback(e)
    return true
  elseif cc.subcommands then
    return Mod.handle_cmd(self, e, cmd, cc.subcommands, ...)
  end
  return false
end

--- @param e down.Event
--- @param self down.Mod
--- @param ... any
--- @return boolean
Mod.handle_event = function(self, e, ...)
  log.trace('Mod.handle_event: Handling event ', e.id, ' for mod ', self.id)
  if self.handle and self.handle[e.split[1]] and self.handle[e.split[1]][e.split[2]] then
    self.handle[e.split[1]][e.split[2]](e)
    return true
  elseif e.split[1] == 'cmd' then
    return Mod.handle_cmd(self, e, e.split[2], self.commands, ...)
  end
  return false
end

--- @param m down.Mod.Mod
--- @param id string
--- @param body table
--- @param ev? table
--- @return down.Event?
function Mod.new_event(m, id, body, ev)
  return Event.new(m, id, body, ev)
end

---@type fun(module: down.Mod.Mod, id: string): down.Event
---@return down.Event
function Mod.define_event(module, nid)
  return Event.define(module, nid)
end

---@param e down.Event
function Mod.broadcast(e)
  Event.handle(e)
  log.trace('Mod.broadcast: Broadcasting event', e.id)
  for mn, m in pairs(Mod.mods) do
    if Mod.handle_event(m, e) then
      log.trace('Mod.broadcast: Broadcast success: ', e.id, ' to mod ', mn)
    end
  end
end

--- Returns an event template defined in `mod.events`.
--- @param m down.Mod.Mod A reference to the mod invoking the function
--- @param id string A full path to a valid event type (e.g. `mod.events.some_event`)
--- @return down.Event?
function Mod.get_event(self, id)
  local split = Event.split_id(id)
  if not split then
    log.warn('Unable to get event template for event' .. tid .. 'and mod' .. self.id)
    return
  end
  log.trace('Returning' .. split[2] .. 'for mod' .. split[1])
  return self.events[split[2]]
end

return Mod
-- ---@param self down.mod.base.Base
-- ---@param modname string
-- __call = function(self, modname, sub)
--   return self.new(modname, sub or {})
-- end,
-- __index = function(self, k)
--   return self.mods[k]
-- end,
-- __newindex = function(self, k, v)
--   self.mods[k] = v
-- end,
-- --- @param self down.mod.base.Base
-- --- @param modname string A path to a mod on disk. A path in down is '.', not '/'.
-- --- @param modcfg table? A config that reflects the structure of `down.config.user.setup["mod.id"].config`.
-- --- @return boolean # Whether the mod was successfully loaded.
-- __index = function(self, modname)
--   return self.load_mod(modname)
-- end,
-- --- @param self down.Mod
-- --- @param modn string A path to a mod on disk. A path in down is '.', not '/'.
-- --- @param cfg table? A config that reflects the structure of `down.config.user.setup["mod.id"].config`.
-- --- @return boolean # Whether the mod was successfully loaded.
-- __newindex = function(self, modn, value)
--   return self.load_mod(modn, value)
-- end,
-- })
