--- down.init - Workspace initialization
--- Handles creating .down/ directory structure and registering workspaces
--- Works in both Neovim plugin context and standalone CLI.

local init = {}

--- Default content for .down/index.md
init.index_template = [=[
# Index

Welcome to your down workspace.

## Getting Started

- Use `down note` to create notes
- Use `down compact` to share your workspace with AI
- Use `down skills` to generate project context

## Quick Links

- [[001-first-note|Your first note]]
]=]

--- Default data store
init.default_data = {
  workspaces = {},
  active = nil,
  default = nil,
}

--- Initialize a down workspace at the given path
---@param root string
---@param opts? { name?: string, force?: boolean }
---@return boolean, string
function init.setup(root, opts)
  opts = opts or {}
  local down_dir = root .. "/.down"
  local data_dir = down_dir .. "/data"

  -- Create directories
  os.execute('mkdir -p "' .. down_dir .. '" 2>/dev/null')
  os.execute('mkdir -p "' .. data_dir .. '" 2>/dev/null')

  -- Create .downignore if not exists
  local ignore_path = down_dir .. "/.downignore"
  local ignore_file = io.open(ignore_path, "r")
  if not ignore_file then
    local f = io.open(ignore_path, "w")
    if f then
      f:write([[
# Files and directories ignored by down compact/add
.git/
.svn/
node_modules/
.downignore
.down/data/.downignore
]])
      f:close()
    end
  else
    ignore_file:close()
  end

  -- Create index.md if not exists
  local index_path = down_dir .. "/index.md"
  local index_file = io.open(index_path, "r")
  if not index_file then
    local f = io.open(index_path, "w")
    if f then
      f:write(init.index_template)
      f:close()
    end
  else
    index_file:close()
  end

  -- Create or update down.json
  local json_path = down_dir .. "/down.json"
  local existing = {}
  local json_file = io.open(json_path, "r")
  if json_file then
    local content = json_file:read("*a")
    json_file:close()
    if content and content ~= "" then
      local ok, parsed = pcall(function()
        return require("json") and require("json").decode(content)
          or load("return " .. content)()
      end)
      if ok and type(parsed) == "table" then
        existing = parsed
      end
    end
  end

  -- Register workspace
  local ws_name = opts.name or root:match("[^/]+$") or "default"
  if not existing.workspaces then existing.workspaces = {} end
  existing.workspaces[ws_name] = root
  if not existing.default then existing.default = ws_name end
  if not existing.active then existing.active = ws_name end

  -- Write JSON manually (no vim.json available in CLI)
  local function json_encode(tbl, indent)
    indent = indent or 0
    local pad = string.rep("  ", indent)
    local pad1 = string.rep("  ", indent + 1)
    if type(tbl) ~= "table" then
      if type(tbl) == "string" then return '"' .. tbl .. '"'
      elseif type(tbl) == "number" then return tostring(tbl)
      elseif type(tbl) == "boolean" then return tbl and "true" or "false"
      else return "null" end
    end
    local parts = {}
    local is_array = true
    local max_idx = 0
    for k in pairs(tbl) do
      if type(k) ~= "number" then is_array = false break end
      if k > max_idx then max_idx = k end
    end
    if is_array and max_idx == #tbl and max_idx > 0 then
      for i, v in ipairs(tbl) do
        parts[#parts + 1] = pad1 .. json_encode(v, indent + 1)
      end
      return "[\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "]"
    else
      for k, v in pairs(tbl) do
        local key = type(k) == "string" and ('"' .. k .. '"') or ('"' .. tostring(k) .. '"')
        parts[#parts + 1] = pad1 .. key .. ": " .. json_encode(v, indent + 1)
      end
      return "{\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "}"
    end
  end

  local f = io.open(json_path, "w")
  if not f then return false, "cannot write " .. json_path end
  f:write(json_encode(existing))
  f:close()

  -- Also update global down.json in ~/.config/down/ if it exists
  local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
  local global_dir = config_home .. "/down"
  local global_json = global_dir .. "/down.json"

  local global_data = {}
  local gf = io.open(global_json, "r")
  if gf then
    local gc = gf:read("*a")
    gf:close()
    if gc and gc ~= "" then
      local ok, parsed = pcall(function() return load("return " .. gc)() end)
      if ok and type(parsed) == "table" then global_data = parsed end
    end
  end

  if not global_data.workspaces then global_data.workspaces = {} end
  global_data.workspaces[ws_name] = root
  if not global_data.default then global_data.default = ws_name end
  if not global_data.active then global_data.active = ws_name end

  os.execute('mkdir -p "' .. global_dir .. '" 2>/dev/null')
  local gf2 = io.open(global_json, "w")
  if gf2 then
    gf2:write(json_encode(global_data))
    gf2:close()
  end

  return true, ws_name
end

--- CLI handler for `down init [path] [--name NAME]`
---@param args table
function init.cli(args)
  local root = nil
  local name = nil
  local i = 1
  while i <= #args do
    local a = args[i]
    if a == "--name" or a == "-n" then
      i = i + 1
      name = args[i]
    elseif a == "--help" or a == "-h" then
      print([[down init - Initialize a down workspace

Usage: down init [options] [path]

Options:
  -n, --name NAME    Workspace name (default: directory name)
  -h, --help         Show this help

Creates .down/index.md, .down/down.json, and .down/data/
Registers the workspace in the global profile.]])
      return true
    elseif a:sub(1, 1) ~= "-" then
      root = a
    end
    i = i + 1
  end

  root = root or io.popen("pwd"):read("*l")
  local ok, ws_name = init.setup(root, { name = name })
  if ok then
    print("Initialized down workspace '" .. ws_name .. "' at " .. root)
    print("  Created .down/index.md")
    print("  Created .down/down.json")
    print("  Created .down/data/")
  else
    print("Error: " .. (ws_name or "unknown"))
  end
  return true
end

return init
