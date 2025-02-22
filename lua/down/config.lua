local log = require("down.util.log")
local mod = require("down.mod")
local modconf = require("down.util.mod")

--- The down.nvim configuration
--- @class down.config.Config
local Config = {
  --- Start in dev mode
  dev = false,
  defaults = true,
  debug = false,
  bench = false,
  test = false,
  --- The user config to load in
  ---@type down.mod.Config
  user = modconf.defaults,
  version = "0.1.2-alpha",
  started = false,
}

---@type down.config.Toggle[]
Config.toggles = {
  "dev",
  "debug",
  "test",
  "defaults",
  "bench",
}

function Config:check_hook(...)
  if self.user.hook and type(self.user.hook) == "function" then
    return self.user.hook(...)
  end
end

---@param k? down.config.Toggle
---@param v? boolean
function Config:check_toggle(k, v)
  if
    k
    and type(k) == "string"
    and v
    and type(v) == "boolean"
    and vim.tbl_contains(self.toggles, k)
  then
    self[k] = v
  end
end

---@param user down.mod.Config user config
---@param ... any
---@return down.config.Config
function Config:load(user, ...)
  if self.started and self.started == false then
    return self
  elseif not type(user) == "table" then
    return self
  elseif user.defaults and user.defaults == false then
    self.user = user
  else
    self.user = vim.tbl_extend("force", user, modconf.defaults)
  end
  vim.iter(pairs(self.user)):map(function(k, v)
    self:check_toggle(k, v)
  end)
  self:check_hook(...)
  self.started = true
end

function Config:post_load()
  return self:check_tests(require("down.mod").mods or self.user) ---@type boolean?
end

--- @param ... string
--- @return string
function Config.vimdir(...)
  local d = vim.fs.joinpath(vim.fn.stdpath("data"), "down/")
  vim.fn.mkdir(d, "p")
  local dir = vim.fs.joinpath("data", ...)
  return dir
end

--- @param ... string
--- @return string
function Config.homedir(...)
  local d = vim.fs.joinpath(os.getenv("HOME") or "~/", ".down/", ...)
  vim.fn.mkdir(d, "p")
  return d
end

--- @param fp? string
--- @return string
function Config:file(fp)
  local f = vim.fs.joinpath(fp or self.vimdir("down.json"))
end

--- @param f string | nil
--- @return down.config.User
function Config.fromfile(f)
  local file = vim.fn.readfile(Config.file(f))
  local conf = vim.json.decode(file) ---@type down.config.User
  return conf
end

--- @param f string | nil
function Config:save(f)
  local json = vim.json.encode(self.user)
  json = vim.fn.str2list(json)
  return vim.fn.writefile(json, self:file(f), "S")
end

--- @param self down.config.Config
---@param user down.mod.Config
---@param ... any
---@return down.config.Config
function Config:setup(user, ...)
  log.new(log.config, false)
  log.info("Config.setup: Log started")
  return self:load(user, ...)
end

---@param mods? { [down.Mod.Id]?: down.Mod.Mod }
---@return boolean?
function Config:check_tests(mods)
  if not self.test then
    return
  elseif self.test == false then
    return false
  elseif self.test and self.test == true then
    return self:tests(mods or vim.iter(self.user or mods):filter(function(m)
      return self.check_mod_test(m)
    end))
  end
end

---@param mod down.Mod.Mod`
---@return boolean
function Config.check_mod_test(mod)
  return mod ~= nil
    and mod.id ~= nil
    and modconf.check_id(mod.id)
    and type(mod) == "table"
    and mod.tests ~= nil
    and type(mod.tests) == "table"
    and not vim.tbl_isempty(mod.tests)
end

---@param mods? down.Mod.Mod[]
---@return boolean
function Config:tests(mods)
  vim.print("Testing config", vim.inspect(self))
  return vim.iter(mods or self.user):filter(self.check_mod_test):all(function(m)
    return self.test(m)
  end)
end

---@param mod down.Mod.Mod
---@return boolean
function Config.test(mod)
  vim.print("Testing " .. tostring(vim.inspect(mod.id)))
  return vim
    .iter(pairs(mod.tests))
    :filter(function(tn, t)
      return tn and type(t) == "function"
    end)
    :all(function(tn, tt)
      if not type(tt) == "function" then
        return false
      end
      local res = tt(mod) or false ---@type boolean
      vim.print(
        "Testing mod " .. mod.id .. " test: " .. tn .. ": " .. tostring(res)
      )
      return res
    end)
end

return Config
