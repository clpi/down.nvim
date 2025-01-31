local Event = require("down.event")
local log = require("down.util.log")
local mod = require("down.mod")
local util = require("down.mod.workspace.util")
local utils = require("down.util")

---@class down.Workspace: string
---@class down.Workspaces: { [string]?: string }

---@class down.mod.workspace.Workspace: down.Mod
local M = mod.new("workspace")

---@return string
M.path = function(name)
  return vim.fs.normalize(vim.fn.resolve(M.data.workspaces[name]))
end

M.home = function()
  return M.path((vim.loop or vim.uv).os_homedir())
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
    rawset(self, key, val)
    M.dep["data"].set("workspace." .. key, self[key])
  end,
  __metatable = "workspace",
  __tostring = function(self)
    if type(self) == "table" then
      return vim.inspect(self)
    elseif type(self) == "string" then
      return "workspace." .. self
    end
    return vim.inspect(self)
  end,
  __index = function(self, key)
    key = "workspace." .. key
    local res = rawget(self, key)
    if not res == M.dep["data"].get("workspace." .. key) then
      M.dep["data"].set("workspace." .. key, res)
    end
    return res
  end,
  ---@param opts { load: boolean, }
  __call = function(self, opts)
    if opts and opts.load and opts.load == true then
      for k, v in pairs(self) do
        if not M.dep.data.get("workspace." .. k) == v then
          rawset(self, k, v)
        end
      end
    else
      for k, v in pairs(self) do
        if not M.dep.data.get(k) == v then
          M.dep.data.set("workspace." .. k, v)
        end
      end
    end
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
      vim.print(require("down.mod.workspace").data)
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

---@return Iter
M.iter = function()
  return vim.iter(pairs(M.data.workspaces))
end

M.load = function()
  M.data.workspaces = M.config.workspaces or M.data.workspaces
  for n, p in pairs(M.data.workspaces) do
    M.data.workspaces[n] = vim.fn.resolve(vim.fs.normalize(p))
  end
  M.data.default = M.config.default or M.data.default or "default"
  M.data.previous = M.data.previous or "default"
  M.data.active = M.data.active or M.data.default
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

---@class down.mod.workspace.Data
M.index = function(p)
  if p then
    return vim.fs.joinpath(p, M.config.index .. M.config.ext)
  end
  return M.config.index .. M.config.ext
end

---@return string
M.current = function()
  return M.data.active
end

---@return string[]
M.files = function(ws, patt)
  return vim.fn.globpath(M.get(ws), patt or "**/*", true, true)
end

---Call attempt to edit a file, catches and suppresses the error caused by a swap file being
---present. Re-raises other errors via log.error
---@param path string
M.edit = function(path)
  vim.cmd("e " .. path)
  -- if not ok and err and not string.match(err, "Vim:E325") then
  --   log.error(string.format("Failed to edit file %s. Error:\n%s", path, err))
  -- end
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
  vim.fn.mkdir(p, "p")
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
  M.commands.workspace.complete = { M.names() }
  M.data.previous = M.data.previous
  M.data.workspaces = M.config.workspaces
  M.data.active = M.data.active or M.data.default
  M.data.history = M.data.history or {}
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
    log.error("Error in fetching workspace path")
    return
  end
  local destination = vim.fs.joinpath(fullpath, path)
  local parent = vim.fs.dirname(destination)
  if not vim.fn.isdirectory(parent) then
    vim.fn.mkdir(parent, "p")
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
  vim.cmd("e " .. vim.fs.joinpath(workspace, path) .. " | silent! w")
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
  return vim.fn.filereadable(filepath)
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
  return vim.fn.globpath(M.get(name), "**/*.md", true, true)
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
  return vim.fn.writefile({}, vim.fs.joinpath(ws_match, p))
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
  return vim.fs.joinpath(wsp, p)
end

M.is_subpath = function(p, wsname)
  local wsp = M.get_dir(wsname)
  return not not p:match("^" .. wsp)
end

M.commands = {
  -- enabled = false,
  index = {
    -- enabled = false,
    args = 0,
    max_args = 1,
    name = "workspace.index",
    complete = { M.names() },
    callback = function(e)
      local index_path = M.index(M.get(M.current()))
      local parent = vim.fs.dirname(index_path)
      if vim.fn.filereadable(index_path) == 0 then
        if not vim.fn.writefile({}, index_path) then
          return
        end
      end
      M.edit(index_path)
    end,
  },
  workspace = {
    max_args = 1,
    name = "workspace.workspace",
    complete = { M.names() },
    callback = function(event)
      if event.body[1] then
        M.open(event.body[1])
        vim.schedule(function()
          local new_workspace = M.get(event.body[1])
          if not new_workspace then
            M.select()
          end
          vim.notify(
            "New workspace: " .. event.body[1] .. " -> " .. new_workspace
          )
        end)
      else
        M.select()
      end
    end,
  },
}

---@class down.mod.workspace.Events
M.events = {
  wschanged = Event.define(M, "wschanged"),
  wsadded = Event.define(M, "wsadded"),
  wscache_empty = Event.define(M, "wscache_empty"),
  file_created = Event.define(M, "file_created"),
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
