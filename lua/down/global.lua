--- down.global - global config store for workspaces and profiles
--- Persists workspaces + profiles to ~/.config/down/down.json so they are
--- tracked globally and can be append-merged from the neovim config.

local M = {}

---@class down.global.Profile
---@field workspaces table<string,string>?
---@field workspace_options table<string, table>?
---@field default string?

---@class down.global.Config
---@field profiles table<string, down.global.Profile>
---@field active_profile string
---@field workspaces table<string,string>  global workspace registry
---@field workspace_options table<string,table>  global workspace metadata

--- Path to the global config file (~/.config/down/down.json)
---@return string
function M.path ()
  local config_home = os.getenv ("XDG_CONFIG_HOME")
  if not config_home or config_home == "" then
    config_home = (os.getenv ("HOME") or "~") .. "/.config"
  end
  return config_home .. "/down/down.json"
end

local function defaults ()
  return {
    profiles = { default = { workspaces = {}, workspace_options = {}, default = nil } },
    active_profile = "default",
    workspaces = {},
    workspace_options = {},
  }
end

--- Load the global config, returning a normalized table.
---@return down.global.Config
function M.load ()
  local f = io.open (M.path (), "r")
  if not f then
    return defaults ()
  end
  local raw = f:read ("*a")
  f:close ()
  if not raw or raw == "" then
    return defaults ()
  end
  local ok, data = pcall (vim.json.decode, raw)
  if not ok or type (data) ~= "table" then
    return defaults ()
  end
  if not data.profiles then
    data.profiles =
      { default = { workspaces = data.workspaces or {}, default = nil } }
  end
  if not data.active_profile then
    data.active_profile = "default"
  end
  if not data.profiles.default then
    data.profiles.default = { workspaces = {}, default = nil }
  end
  if not data.workspaces then
    data.workspaces = {}
  end
  if not data.workspace_options then
    data.workspace_options = {}
  end
  -- Ensure every profile has a workspaces table and metadata table
  for _, p in pairs (data.profiles) do
    if not p.workspaces then
      p.workspaces = {}
    end
    if not p.workspace_options then
      p.workspace_options = {}
    end
  end
  return data
end

--- Persist the global config to disk.
---@param data down.global.Config
function M.save (data)
  local p = M.path ()
  vim.fn.mkdir (vim.fn.fnamemodify (p, ":h"), "p")
  local f = io.open (p, "w")
  if f then
    f:write (vim.json.encode (data))
    f:close ()
  end
end

--- Return the active profile name.
---@return string
function M.active_profile ()
  return M.load ().active_profile or "default"
end

--- Set the active profile and persist.
---@param name string
function M.set_active_profile (name)
  local data = M.load ()
  if not data.profiles[name] then
    return false
  end
  data.active_profile = name
  M.save (data)
  return true
end

--- Append-merge a workspace map into the global registry and into the
--- active profile's workspaces. Existing entries are kept (config does
--- not overwrite paths already registered globally).
---@param workspaces table<string,string>  map of name -> path
---@param profile_name? string             profile to merge into (default: active)
---@param options table<string,table>?     map of name -> metadata
---@return down.global.Config data          the resulting global config
function M.merge_workspaces (workspaces, profile_name, options)
  local data = M.load ()
  profile_name = profile_name or data.active_profile or "default"
  if not data.profiles[profile_name] then
    data.profiles[profile_name] = { workspaces = {}, workspace_options = {}, default = nil }
  end
  local profile = data.profiles[profile_name]
  for name, path in pairs (workspaces or {}) do
    if name and name ~= "" and path and path ~= "" then
      data.workspaces[name] = path
      profile.workspaces[name] = path
      if options and options[name] then
        data.workspace_options[name] = options[name]
        profile.workspace_options[name] = options[name]
      end
    end
  end
  M.save (data)
  return data
end

--- Add a single workspace to the global registry + active profile.
---@param name string
---@param path string
---@param profile_name? string
---@param options table?
function M.add_workspace (name, path, profile_name, options)
  M.merge_workspaces ({ [name] = path }, profile_name, options and { [name] = options } or nil)
end

--- Remove a workspace from the global registry + a profile (or all profiles).
---@param name string
---@param profile_name? string  nil removes from every profile
function M.remove_workspace (name, profile_name)
  local data = M.load ()
  data.workspaces[name] = nil
  data.workspace_options[name] = nil
  if profile_name then
    if data.profiles[profile_name] then
      data.profiles[profile_name].workspaces[name] = nil
      data.profiles[profile_name].workspace_options[name] = nil
    end
  else
    for _, p in pairs (data.profiles) do
      if p.workspaces then
        p.workspaces[name] = nil
      end
      if p.workspace_options then
        p.workspace_options[name] = nil
      end
    end
  end
  M.save (data)
end

--- Rename a workspace across the global registry + all profiles.
---@param old_name string
---@param new_name string
function M.rename_workspace (old_name, new_name)
  local data = M.load ()
  if data.workspaces[old_name] then
    data.workspaces[new_name] = data.workspaces[old_name]
    data.workspaces[old_name] = nil
  end
  if data.workspace_options[old_name] then
    data.workspace_options[new_name] = data.workspace_options[old_name]
    data.workspace_options[old_name] = nil
  end
  for _, p in pairs (data.profiles) do
    if p.workspaces and p.workspaces[old_name] then
      p.workspaces[new_name] = p.workspaces[old_name]
      p.workspaces[old_name] = nil
      if p.default == old_name then
        p.default = new_name
      end
    end
    if p.workspace_options and p.workspace_options[old_name] then
      p.workspace_options[new_name] = p.workspace_options[old_name]
      p.workspace_options[old_name] = nil
    end
  end
  M.save (data)
end

--- Return the workspaces registered for a profile (default: active).
---@param profile_name? string
---@return table<string,string>
function M.profile_workspaces (profile_name)
  local data = M.load ()
  profile_name = profile_name or data.active_profile or "default"
  local p = data.profiles[profile_name]
  if not p then
    return {}
  end
  return p.workspaces or {}
end

--- Return workspace metadata registered for a profile (default: active).
---@param profile_name? string
---@return table<string,table>
function M.profile_workspace_options (profile_name)
  local data = M.load ()
  profile_name = profile_name or data.active_profile or "default"
  local p = data.profiles[profile_name]
  if not p then
    return {}
  end
  return p.workspace_options or {}
end

--- Add a new profile (empty workspaces) to the global config.
---@param name string
function M.add_profile (name)
  local data = M.load ()
  if not data.profiles[name] then
    data.profiles[name] = { workspaces = {}, workspace_options = {}, default = nil }
    M.save (data)
  end
end

--- Remove a profile from the global config.
---@param name string
function M.remove_profile (name)
  if name == "default" then
    return false
  end
  local data = M.load ()
  data.profiles[name] = nil
  if data.active_profile == name then
    data.active_profile = "default"
  end
  M.save (data)
  return true
end

--- Return all profile names.
---@return string[]
function M.profile_names ()
  local data = M.load ()
  local names = {}
  for n in pairs (data.profiles or {}) do
    names[#names + 1] = n
  end
  table.sort (names)
  return names
end

return M
