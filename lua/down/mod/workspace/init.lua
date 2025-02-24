local event = require("down.event")
local log = require("down.util.log")
local mod = require("down.mod")
local util = require("down.mod.workspace.util")
local utils = require("down.util")

local fn, fs, it, uv, dbg =
  vim.fn, vim.fs, vim.iter, (vim.uv or vim.loop), vim.print

---@class down.Workspace: string
---@class down.Workspaces: { [string]?: string }

---@class down.mod.workspace.Workspace: down.Mod
local M = mod.new("workspace")

---@return string
M.path = function(name)
  return fs.normalize(fn.resolve(fn.expand(M.data.workspaces[name])))
end

M.home = function()
  return M.path(uv.os_homedir())
end

---@class down.mod.workspace.Data
M.data = setmetatable({
  ---@type down.Workspaces
  workspaces = {},
  ---@type down.Workspace[]
  history = {},
  ---@type string?
  active = nil,
  ---@type string?
  default = nil,
  ---@type string?
  previous = nil,
}, {
  __concat = function(self, key)
    if type(key) == "string" then
      return tostring(self) .. key
    end
  end,
  __newindex = function(self, key, val)
    -- vim.notify("setting " .. key .. " to " .. vim.inspect(val))
    rawset(self, key, val)
    M.dep["data"].set("workspace." .. key, self[key])
    M.dep.data.flush()
  end,
  __tostring = function(self)
    if type(self) == "table" then
      return vim.inspect(self)
    elseif type(self) == "string" then
      return "workspace." .. self
    end
    return vim.inspect(self)
  end,
  __name = "workspace",
  __index = function(self, key)
    key = "workspace." .. key
    local res = rawget(self, key)
    if not res == M.dep["data"].get("workspace." .. key) then
      M.dep["data"].set("workspace." .. key, res)
      M.dep.data.flush()
    end
    return res
  end,
  ---@param opts { load: boolean, }
  __call = function(self, opts)
    if opts and opts.load and opts.load == true then
      for k, v in pairs(self) do
        if not M.dep.data.get("workspace." .. k) then
          M.dep.data.set("workspace." .. k, v)
        end
        if not M.dep.data.get("workspace." .. k) == v then
          rawset(self, k, M.dep.data.get("workspace." .. k))
        end
      end
    else
      for k, v in pairs(self) do
        if not M.dep.data.get(k) == v then
          M.dep.data.set("workspace." .. k, v)
        end
      end
    end
    M.dep.data.flush()
  end,
})

---@class down.mod.workspace.Config
M.config = {
  --- default workspace
  default = "default",
  --- List of workspaces
  workspaces = {
    default = vim.fn.getcwd(0),
    cwd = vim.fn.getcwd(0),
  },
  --- The filetype of new douments, markdown is supported only for now
  ft = "markdown",
  --- The default index to use
  index = "index",
  ext = ".md",
  -- if `false`, will use vim's default `vim.ui.input` instead.
  use_popup = true,
}

---@return down.mod.Setup
M.setup = function()
  return {
    loaded = true,
    dependencies = { "ui", "data", "note", "cmd" },
  }
end

M.maps = {
  {
    "n",
    ",D",
    function()
      dbg(M.data)
    end,
    "hi",
  },
  {
    "n",
    ",dfw",
    "<CMD>Telescope down workspace<CR>",
    "Telescope down workspaces",
  },
  { "n", ",d.", "<CMD>Down workspace cwd<CR>", "Down workspace in cw" },
  { "n", ",di", "<CMD>Down index<CR>", "Down index" },
  { "n", ",dw", "<CMD>Down workspace<CR>", "Down workspaces" },
  {
    "n",
    ",dfw",
    "<CMD>Telescope down workspace<CR>",
    "Telescope down workspaces",
  },
  { "n", ",d.", "<CMD>Down workspace cwd<CR>", "Down workspace in cw" },
}

--- Returns an iterator for the workspaces
--- @return Iter
M.iter = function()
  return vim.iter(pairs(M.data.workspaces))
end

--- Returns the workspace folder as lsp
--- @return lsp.WorkspaceFolder
--- @param name? string
--- @param path? string
M.as_lsp_workspace = function(name, path)
  return {
    name = name or M.data.active,
    uri = vim.uri_from_fname(path or M.path(name or M.data.active)),
  }
end

--- Returns the workspace folders as lsp
--- @return lsp.WorkspaceFolder[]
M.as_lsp_workspaces = function()
  return vim.iter(M.data.workspaces):map(M.as_lsp_workspace):totable()
end

--- Loads the workspace module
M.load = function()
  vim.iter(M.config.workspaces):each(function(k, v)
    M.config.workspaces[k] = fs.normalize(fn.resolve(fn.expand(v)))
  end)
  M.data.workspaces = M.config.workspaces or M.data.workspaces or {}
  M.data.history = M.data.history or {}
  M.data.default = M.config.default or M.data.default or "default"
  M.data.previous = M.data.previous or "default"
  M.data.active = M.data.active or M.data.default or "default"
  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*",
    callback = function()
      mod.await("cmd", function(cmd)
        cmd.add_commands_from_table(M.commands)
      end)
    end,
  })
  M.sync()
end

--- Returns the index file for a workspace
---@class down.mod.workspace.Data
M.index = function(p)
  return vim.fs.joinpath(p or M.current_path(), M.config.index .. M.config.ext)
end

--- Returns the current workspace name
--- @return string
M.current = function()
  return M.data.active
end

--- Returns the current workspace path
--- @return string
M.current_path = function()
  return M.path(M.data.active)
end

--- Returns all files in a workspace
--- @return string[]
M.files = function(ws, patt)
  return vim.fn.globpath(M.get(ws), patt or "**/*", true, true)
end

--- Opens a file in the current workspace or at path
---@param path string
M.edit = function(path)
  vim.cmd("silent! e " .. path or M.index())
end

--- If present retrieve a workspace's path by its name, else returns nil
---@param name string #The name of the workspace
M.get = function(name)
  if not name then
    return M.data.workspaces[M.data.active]
  end
  return M.data.workspaces[name]
end

M.set = function(name, path)
  M.data.workspaces[name] = M.path(path)
end
M.has = function(n)
  return M.data.workspaces[n] ~= nil
end
--- Sets the workspace to the one specified (if it exists) and broadcasts the wschanged event
---@param n string #The name of a valid namespace we want to switch to
---@param create? boolean
---@return boolean #True if the workspace is set correctly, false otherwise
M.set_workspace = function(n, create)
  if not M.has(n) then
    log.warn(
      "Unable to set workspace to" .. n .. "- that workspace does not exist"
    )
    return false
  end
  local p = M.path(M.data.workspaces[n])
  fn.mkdir(p, "p")
  M.data.previous = M.data.active
  M.data.active = n
  -- local e = mod.new_event(M, 'workspace.events.wschanged', { old = ws, new = workspace })
  -- mod.broadcast(e or {})

  return true
end
--- Dynamically defines a new workspace if the name isn't already occupied and broadcasts the wsadded event
---@return boolean True if the workspace is added successfully, false otherwise
---@param wsname string #The unique name of the new workspace
---@param wspath string #A full path to the workspace root
M.add_workspace = function(wsname, wspath)
  if M.data.workspaces[wsname] then
    return false
  end
  wspath = M.path(wspath)
  M.data.workspaces[wsname] = M.path(wspath)
  mod.broadcast(
    mod.new_event(M, "workspace.events.wsadded", { wsname, wspath }) or {}
  )
  M.sync()
  return true
end

--- Updates completions for the :down command
M.sync = function()
  M.data.workspaces = M.data.workspaces
  M.dep.data.data.workspaces = M.data.workspaces
  -- M.dep.data.set("workspace.workspaces", M.data.workspaces)
  M.commands.workspace.complete = { M.names() }
  M.data.previous = M.data.previous
  M.data.workspaces = M.config.workspaces or {}
  M.data.active = M.data.active or M.data.default
  M.data.history = M.data.history or {}
  M.dep.data.flush()
  mod.await("cmd", function(cmd)
    cmd.add_commands_from_table(M.commands)
  end)
end
--- @param prompt? string | nil
--- @param fmt? fun(item: string): string
--- @param fn? fun(item: number|string, idx: number|string)|nil
M.select = function(prompt, fmt, fn)
  local format = fmt
    or function(item)
      local current = M.current()
      if item == current then
        return "• " .. item
      end
      return item
    end
  local func = fn
    or function(item, idx)
      local current = M.current()
      if not item then
        return
      elseif item == current then
        vim.notify("Already in workspace " .. current)
      else
        vim.notify("Workspace set to " .. item)
        M.set_workspace(item)
      end
      M.open(item)
    end
  return vim.ui.select(M.names(), {
    prompt = prompt or "Select workspace",
    format_items = format,
  }, func)
end
M.gets = function()
  return M.data.workspaces
end
M.set_selected = function()
  local workspace = M.select()
  M.set_workspace(workspace or M.data.default or "default")
  vim.notify("Changed workspace to " .. workspace)
end

---@class down.mod.workspace.CreateFileOpts
---@field open? boolean do not open the file after creation?
---@field force? boolean overwrite file if it already exists?

--- Takes in a path (can include directories) and creates a .down file from that path
---@param path string
---@param workspace? string workspace name
---@param opts? down.mod.workspace.CreateFileOpts
M.new_file = function(path, workspace, opts)
  opts = opts or { open = true, force = false }
  local fullpath
  if workspace ~= nil then
    fullpath = M.get(workspace)
  else
    fullpath = M.current()[2]
  end
  if fullpath == nil then
    return log.error("Error in fetching workspace path")
  end
  local destination = fs.joinpath(fullpath, path)
  local parent = fs.dirname(destination)
  if not fn.isdirectory(parent) then
    fn.mkdir(parent, "p")
  end
  -- mod.broadcast(
  --   mod.new_event(
  --     M,
  --     "workspace.events.file_created",
  --     { buffer = vim.api.nvim_get_current_buf(), opts = opts }
  --   ) or {}
  -- )
  if opts.open then
    vim.cmd("e " .. destination .. "| silent! w")
  end
end

--- Takes in a workspace name and a path for a file and opens it
---@param wsname string #The name of the workspace to use
---@param path string #A path to open the file (e.g directory/filename.down)
M.open_file = function(wsname, path)
  local workspace = M.get(wsname)
  if workspace == nil then
    return
  end
  vim.cmd("e " .. fs.joinpath(workspace, path) .. " | silent! w")
end
M.set_last_workspace = function()
  local prev = M.data.previous or M.data.default or ""
  local wspath = M.get(M.data.previous)
  if not wspath then
    log.trace(
      "Unable to switch to workspace '"
        .. prev
        .. "'. The workspace does not exist."
    )
    return
  end
  if M.set_workspace(prev) then
    vim.cmd("e " .. M.index(wspath))
    vim.notify("Last workspace -> " .. wspath)
  end
end
--- Checks for file existence by supplying a full path in `filepath`
---@param filepath string
M.exists = function(filepath)
  return fn.filereadable(filepath)
end
--- Get the bufnr for a `filepath` (full path)
---@param filepath string
M.bufnr = function(filepath)
  if M.exists(filepath) then
    local uri = vim.uri_from_fname(tostring(filepath))
    return vim.uri_to_bufnr(uri)
  end
end
--- Returns a list of all files relative path from a `wsname`
---@param wsname string
---@return string?
M.notes = function(wsname, year, month)
  local workspace = M.get(wsname)
  if not workspace then
    return
  end
  local nd = mod.get_mod("note").config.note_folder
  local wn = vim.fs.joinpath(workspace, nd)
  return vim.fn.globpath(wn, "**/*.md", true, true)
end

M.names = function()
  return vim.tbl_keys(M.data.workspaces)
end

M.workspaces = function()
  return M.data.workspaces
end

M.paths = function()
  return vim.tbl_values(M.data.workspaces)
end
--- Returns a list of all files relative path from a `wsname`
---@param name string
---@return string[]?
M.markdown = function(name)
  return fn.globpath(M.get(name), "**/*.md", true, true)
end
--- Sets the current workspace and opens that workspace's index file
---@param workspace string #The name of the workspace to open
M.open = function(workspace)
  local ws_match = M.get(workspace)
  if not ws_match then
    log.error(
      'Unable to switch to workspace - "' .. workspace .. '" does not exist'
    )
    return
  end
  M.set_workspace(workspace)
  if workspace ~= "default" then
    vim.cmd("e " .. M.index(ws_match))
  end
end
--- Touches a file in workspace
---@param p string
---@param workspace string
M.touch = function(p, workspace)
  vim.validate({
    path = { p, "string", "table" },
    workspace = { workspace, "string" },
  })
  local ws_match = M.get(workspace)
  if not workspace then
    return false
  end
  return fn.writefile({}, fs.joinpath(ws_match, p))
end
M.new_note = function()
  if M.config.use_popup then
    M.dep.ui.new_prompt("downNewNote", "New Note: ", function(text)
      M.new_file(text)
    end, {
      center_x = true,
      center_y = true,
    }, {
      width = 25,
      height = 1,
      row = 10,
      col = 0,
    })
  else
    vim.ui.input({ prompt = "New Note: " }, function(text)
      if text ~= nil and #text > 0 then
        M.new_file(text)
      end
    end)
  end
end

M.subpath = function(p, wsname)
  local wsp = M.get_dir(wsname)
  return fs.joinpath(wsp, p)
end

M.is_subpath = function(p, wsname)
  local wsp = M.get_dir(wsname)
  return not not p:match("^" .. wsp)
end

--- Edit index of current directory
--- @param e down.Event
M.edit_index = function(e)
  local c = e.body[1] or M.current()
  local ws = fs.normalize(fn.expand(M.get(c)))
  fn.mkdir(ws, "p")
  local index = M.index(ws)
  if fn.filereadable(index) == 0 then
    if not fn.writefile({}, index) then
      return vim.notify("Failed to create index file")
    end
  end
  M.edit(index)
end

--- Select workspace
--- @param e down.Event
M.menu = function(e)
  if e.body and e.body[1] then
    M.open(e.body[1])
    vim.schedule(function()
      local new_workspace = M.get(e.body[1])
      if not new_workspace then
        M.select()
      end
      vim.notify("Workspace: " .. e.body[1] .. " -> " .. new_workspace)
    end)
  else
    M.select()
  end
end

M.fmt = function()
  return vim
    .iter(M.workspaces())
    :map(function(k, v)
      return k .. " -> " .. v
    end)
    :totable()
end

---@class down.mod.workspace.Commands: { [string]: down.Command }
M.commands = {
  index = {
    enabled = true,
    min_args = 0,
    max_args = 1,
    name = "workspace.index",
    complete = { M.names() },
    callback = function(e)
      M.edit_index(e)
    end,
  },
  workspace = {
    max_args = 1,
    enabled = true,
    name = "workspace.workspace",
    complete = { M.names() },
    callback = function(e)
      M.menu(e)
    end,
  },
}

---@class down.mod.workspace.Events
M.events = {
  wschanged = event.define(M, "wschanged"),
  wsadded = event.define(M, "wsadded"),
  wscache_empty = event.define(M, "wscache_empty"),
  file_created = event.define(M, "file_created"),
}

---@class down.mod.workspace.Subscribed
M.handle = {
  workspace = {
    wsadded = function(e)
      log.trace(e, "wsadded")
    end,
    file_created = function(e)
      log.trace("filecreated", e)
    end,
    wscache_empty = function(e)
      log.trace("wscache_empty", e)
    end,
    wschanged = function(e)
      log.trace("wschanged", e)
    end,
  },
}

return M
