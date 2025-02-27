local config = require("down.config")
local log = require("down.util.log")
local mod = require("down.mod")
local api, fn, fs, uv = vim.api, vim.fn, vim.fs, (vim.uv or vim.loop)
local stdp, join = fn.stdpath, fs.joinpath

---@class down.mod.data.Data: down.Mod
local M = mod.new("data")

---@class down.mod.data.Data.Data
M.data = {}

--- @return down.mod.Setup
M.setup = function()
  api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      M.flush()
    end,
  })
  M.sync()
  ---@type down.mod.Setup
  return {
    loaded = true,
    dependencies = {},
  }
end

M.load = function() end

---@class down.mod..Config
M.config = {
  path = stdp("data") .. "/down.json",
  dir = {
    vim = join(stdp("data") or fn.expand("~/.local/share/nvim"), "down/"),
    home = join(os.getenv("HOME") or "~/", ".down/"),
  },
  file = {
    vim = join(
      stdp("data") or fn.expand("~/.local/share/nvim"),
      "down/",
      "down.json"
    ),
    home = join(os.getenv("HOME") or "~/", ".down/", "down.json"),
  },
}

---@param name string
---@type fun(name: string): metatable
---@return metatable
M.mt = function(name)
  ---@type metatable
  return {
    ---@param self down.Mod.Mod
    __tostring = function(self)
      return name
    end,
    ---@param self down.Mod.Mod
    __index = function(self, key)
      if not self[name .. "." .. key] then
        return
      end
      if not B.dep.data.get(key) == self[key] then
        B.dep.data.set(name .. "." .. key, self[key])
      end
      return self[key]
    end,
    __name = name,
    ---@param self down.Mod.Mod
    __newindex = function(self, key, val)
      self[key] = val
      B.dep.data.set(name .. "." .. key, val)
    end,
    ---@param a down.Mod.Mod
    __concat = function(a, b)
      if type(b) == "string" then
        return tostring(a) .. "." .. b
      end
      return tostring(a) .. tostring(b)
    end,
    ---@param self down.Mod.Mod
    ---@param load? boolean
    __call = function(self, load)
      for key, val in pairs(self) do
        if load then
          self[key] = M.data.get(name .. "." .. key)
        elseif
          not M.dep.data.get(name .. "." .. key)
          or not M.dep.data.get(name .. "." .. key) == val
        then
          M.dep.data.set(name .. "." .. key, val)
        end
      end
      M.flush()
    end,
  }
end

---@generic T: table
---@param name string
---@param t T
---@return T
M.tbl = function(name, t)
  return setmetatable(t, M.mt(name))
end

M.concat = function(p1, p2)
  return table.concat({ p1, require("down.util").sep, p2 })
end

--- @param path string
--- @param cond? fun(name: string, ends: string): boolean
--- @return table<string>
M.files = function(path, cond)
  local f = {}
  local dir = path or vim.fs.root(vim.fn.cwd(), ".down/")
  for name, type in vim.fs.dir(dir) do
    if type == "file" and cond or name:endswith(".md") then
      table.insert(f, name)
    elseif type == "directory" and not name:startswith(".") then
      local fs = M.get_files(M.concat(path, name))
      for _, v in ipairs(fs) do
        table.insert(f, v)
      end
    end
  end
end

M.directory_map = function(path, callback)
  for name, type in vim.fs.dir(path) do
    if type == "directory" then
      M.directory_map(M.concat(path, name), callback)
    else
      callback(name, type, path)
    end
  end
end

--- Recursively copies a directory froM.handlee path to another
---@param old_path string #The path to copy
---@param new_path string #The new location. This function will not
--- succeed if the directory already exists.
---@return boolean #If true, the directory copying succeeded
M.copy_directory = function(old_path, new_path)
  local file_permissions = tonumber("744", 8)
  local ok, err = vim.loop.fs_mkdir(new_path, file_permissions)

  if not ok then
    return ok, err ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
  end

  for name, type in vim.fs.dir(old_path) do
    if type == "file" then
      ok, err =
        vim.loop.fs_copyfile(M.concat(old_path, name), M.concat(new_path, name))

      if not ok then
        return ok, err ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
      end
    elseif type == "directory" and not vim.endswith(new_path, name) then
      ok, err =
        M.copy_directory(M.concat(old_path, name), M.concat(new_path, name))

      if not ok then
        return ok, err ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
      end
    end
  end

  return true, nil ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
end
--- Grabs the data present on disk and overwrites it with the data present in memory
M.sync = function()
  local file = io.open(M.config.path, "r")
  if not file then
    return
  end
  local content = file:read("*a")
  file:close()
  M.data = vim.json.decode and vim.json.decode(content)
end

--- Stores a key-value pair in the store
---@param key string #The key to index in the store
---@param data any #The data to store at the specific key
M.put = function(key, data)
  M.data[key] = data
  M.flush()
end

M.set = M.put

--- Removes a key from store
---@param key string #The name of the key to remove
M.del = function(key)
  M.data[key] = nil
end

--- Retrieves a key from the store
---@param key string #The name of the key to index
---@return any|table #The data present at the key, or an empty table
M.get = function(key)
  return M.data[key] or {}
end

M.json = function(path)
  local dir = M.config.dir.home
  local vim = M.config.dir.vim
  vim.fn.mkdir(dir, "p")
  vim.fn.mkdir(vim, "p")
  local f = io.open(path or M.config.file.vim, "w")
  f:write(vim.json.encode(M.data))
end
--- Flushes the contents in memory to the location specified
M.flush = function(path)
  local file = io.open(path or M.config.path, "w")
  if not file then
    return
  end
  file:write(vim.json.encode and vim.json.encode(M.data))
  file:close()
end

-- M.handle = {}

return M
