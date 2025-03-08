local config = require("down.config")
local log = require("down.util.log")
local mod = require("down.mod")
local api, fn, fs, uv = vim.api, vim.fn, vim.fs, (vim.uv or vim.loop)
local stdp, join = fn.stdpath, fs.joinpath

---@class down.mod.data.Data: down.Dataod
local Data = mod.new("data")

---@class down.mod.data.Data.Data
Data.data = {}

--- @return down.mod.Setup
Data.setup = function()
  api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      Data.flush()
    end,
  })
  Data.sync()
  ---@type down.mod.Setup
  return {
    loaded = true,
    dependencies = {},
  }
end

Data.load = function() end

---@class down.mod..Config
Data.config = {
  path = stdp("data") .. "/down.json",
  dir = {
    vim = join(stdp("data") or fn.expand("~/.local/share/nvim"), "down/"),
    home = join(os.getenv("HODataE") or "~/", ".down/"),
  },
  file = {
    vim = join(
      stdp("data") or fn.expand("~/.local/share/nvim"),
      "down/",
      "down.json"
    ),
    home = join(os.getenv("HODataE") or "~/", ".down/", "down.json"),
  },
}

---@param name string
---@type fun(name: string): metatable
---@return metatable
Data.mt = function(name)
  ---@type metatable
  return {
    ---@param self down.Dataod.Dataod
    __tostring = function(self)
      return name
    end,
    ---@param self down.Dataod.Dataod
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
    ---@param self down.Dataod.Dataod
    __newindex = function(self, key, val)
      self[key] = val
      B.dep.data.set(name .. "." .. key, val)
    end,
    ---@param a down.Dataod.Dataod
    __concat = function(a, b)
      if type(b) == "string" then
        return tostring(a) .. "." .. b
      end
      return tostring(a) .. tostring(b)
    end,
    ---@param self down.Dataod.Dataod
    ---@param load? boolean
    __call = function(self, load)
      for key, val in pairs(self) do
        if load then
          self[key] = Data.data.get(name .. "." .. key)
        elseif
            not Data.dep.data.get(name .. "." .. key)
            or not Data.dep.data.get(name .. "." .. key) == val
        then
          Data.dep.data.set(name .. "." .. key, val)
        end
      end
      Data.flush()
    end,
  }
end

---@generic T: table
---@param name string
---@param t T
---@return T
Data.tbl = function(name, t)
  return setmetatable(t, Data.mt(name))
end

Data.concat = function(p1, p2)
  return table.concat({ p1, require("down.util").sep, p2 })
end

--- @param path string
--- @param cond? fun(name: string, ends: string): boolean
--- @return table<string>
Data.files = function(path, cond)
  local f = {}
  local dir = path or vim.fs.root(vim.fn.cwd(), ".down/")
  for name, type in vim.fs.dir(dir) do
    if type == "file" and cond or name:endswith(".md") then
      table.insert(f, name)
    elseif type == "directory" and not name:startswith(".") then
      local fs = Data.get_files(Data.concat(path, name))
      for _, v in ipairs(fs) do
        table.insert(f, v)
      end
    end
  end
end

Data.directory_map = function(path, callback)
  for name, type in vim.fs.dir(path) do
    if type == "directory" then
      Data.directory_map(Data.concat(path, name), callback)
    else
      callback(name, type, path)
    end
  end
end

--- Recursively copies a directory froData.handlee path to another
---@param old_path string #The path to copy
---@param new_path string #The new location. This function will not
--- succeed if the directory already exists.
---@return boolean #If true, the directory copying succeeded
Data.copy_directory = function(old_path, new_path)
  local file_permissions = tonumber("744", 8)
  local ok, err = vim.loop.fs_mkdir(new_path, file_permissions)

  if not ok then
    return ok, err ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
  end

  for name, type in vim.fs.dir(old_path) do
    if type == "file" then
      ok, err =
          vim.loop.fs_copyfile(Data.concat(old_path, name), Data.concat(new_path, name))

      if not ok then
        return ok, err ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
      end
    elseif type == "directory" and not vim.endswith(new_path, name) then
      ok, err =
          Data.copy_directory(Data.concat(old_path, name), Data.concat(new_path, name))

      if not ok then
        return ok, err ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
      end
    end
  end

  return true, nil ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
end
--- Grabs the data present on disk and overwrites it with the data present in memory
Data.sync = function()
  local file = io.open(Data.config.path, "r")
  if not file then
    return
  end
  local content = file:read("*a")
  file:close()
  Data.data = vim.json.decode and vim.json.decode(content)
end

--- Stores a key-value pair in the store
---@param key string #The key to index in the store
---@param data any #The data to store at the specific key
Data.put = function(key, data)
  Data.data[key] = data
  Data.flush()
end

Data.set = Data.put

--- Removes a key from store
---@param key string #The name of the key to remove
Data.del = function(key)
  Data.data[key] = nil
end

--- Retrieves a key from the store
---@param key string #The name of the key to index
---@return any|table #The data present at the key, or an empty table
Data.get = function(key)
  return Data.data[key] or {}
end

Data.json = function(path)
  local dir = Data.config.dir.home
  local vim = Data.config.dir.vim
  vim.fn.mkdir(dir, "p")
  vim.fn.mkdir(vim, "p")
  local f = io.open(path or Data.config.file.vim, "w")
  f:write(vim.json.encode(Data.data))
end
--- Flushes the contents in memory to the location specified
Data.flush = function(path)
  local file = io.open(path or Data.config.path, "w")
  if not file then
    return
  end
  file:write(vim.json.encode and vim.json.encode(Data.data))
  file:close()
end

-- Data.handle = {}

return Data
