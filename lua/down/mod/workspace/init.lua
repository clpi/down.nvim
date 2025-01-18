local Path = require 'pathlib'
local Event = require 'down.event'
local config = require 'down.config'
local log = require 'down.util.log'
local util = require 'down.mod.workspace.util'
local map = require 'down.util.maps'
local mod = require 'down.mod'
local utils = require 'down.util'
local path = require 'plenary.path'
local notify = util.notify

---@alias down.mod.Workspace down.Mod
---@type down.mod.Workspace
local M = mod.new 'workspace'

---@todo TODO: Merge M.config.default and M.config.workspaces.default

---@class down.mod.workspace.Config
M.config = {
  --- default workspace
  default = 'default',
  --- List of workspaces
  workspaces = {
    default = vim.fn.getcwd(0),
    cwd = vim.fn.getcwd(0),
  },
  ---- The active workspace
  active = Path.cwd(),
  --- The filetype of new douments, markdown is supported only for now
  ft = 'markdown',
  open_last_workspace = false,
  --- The default index to use
  index = 'index',
  ext = '.md',
  -- if `false`, will use vim's default `vim.ui.input` instead.
  use_popup = true,
}

---@return down.mod.Setup
M.setup = function()
  return {
    loaded = true,
    dependencies = { 'ui', 'data', 'note', 'cmd' },
  }
end

M.maps = {
  { 'n', ',di',  '<CMD>Down index<CR>',               'Down index' },
  { 'n', ',dw',  '<CMD>Down workspace<CR>',           'Down workspaces' },
  { 'n', ',dfw', '<CMD>Telescope down workspace<CR>', 'Telescope down workspaces' },
  { 'n', ',d.',  '<CMD>Down workspace cwd<CR>',       'Down workspace in cwd' },
}

M.load = function()
  for name, wsloc in pairs(M.config.workspaces) do
    M.config.workspaces[name] = Path(wsloc):resolve():to_absolute()
  end
  vim.api.nvim_create_autocmd('BufEnter', {
    pattern = '*',
    callback = function()
      mod.await('cmd', function(cmd)
        cmd.add_commands_from_table(M.commands)
      end)
    end
  })
  M.sync()
  if M.config.open_last_workspace and vim.fn.argc(-1) == 0 then
    if M.config.open_last_workspace == 'default' then
      if not M.config.default then
        log.warn 'Configuration error in `default.workspace`: the `open_last_workspace` option is set to "default", but no default workspace is provided in the `default_workspace` configuration variable. defaulting to opening the last known workspace.'
        M.set_last_workspace()
        return
      end
      M.open_workspace(M.config.default)
    else
      M.set_last_workspace()
    end
  elseif M.config.default then
    M.set_workspace(M.config.default)
  end
end

---@class down.mod.workspace.Data
M.indexfmt = function()
  return M.config.index .. M.config.ext
end
---@type { [1]: string, [2]: PathlibPath }
M.current_workspace = { 'default', Path.cwd() }
M.history = {}
M.new_missing_file = function(path) end
M.current = function()
  return M.current_workspace
end
M.files = function(ws)
  local res = {}
  local w = M.get_workspace(ws)
  if not w then
    return
  end
  for p in w:fs_iterdir(true, 20) do
    if p:is_file(true) and path:suffix() == '.md' then
      table.insert(res, path)
    end
  end
  return res
end
---Resolve `$<workspace>/path/to/file` and return the real path
---@param path string | PathlibPath # path
---@param raw_path boolean? # If true, returns resolved path, otherwise, returns resolved path
---and append ".down"
---@param host_file string | PathlibPath | nil file the link resides in, if the link is
---relative, this file is used instead of the current file
---@return PathlibPath?, boolean? # Resolved path. If path does not start with `$` or not absolute, adds
---relative from current file.
M.expand_pathlib = function(path, raw_path, host_file)
  local relative = false
  if not host_file then
    host_file = vim.fn.expand '%:p'
  end
  local filepath = Path(path)
  local custom_wspath = filepath:match '^%$([^/\\]*)[/\\]'
  if custom_wspath then
    if #custom_wspath == 0 then
      filepath = M.get_current_workspace()[2] / filepath:relative_to(Path '$')
    else
      local workspace = ws.get_workspace(custom_wspath)
      if not workspace then
        log.warn("Unable to expand path: workspace '%s' does not exist"):format(custom_wspath)
        return
      end
      filepath = ws / filepath:relative_to(Path('$' .. custom_wspath))
    end
  elseif filepath:is_relative() then
    relative = true
    local this_file = Path(host_file):absolute()
    filepath = this_file:parent_assert() / filepath
  else
    filepath = filepath:absolute()
  end
  if not raw_path then
    if type(path) == 'string' and (path:sub(#path) == '/' or path:sub(#path) == '\\') then
      log.error(({
        'md file loc cannot point to a directory.',
        ("Current link points to '%s'"):format(path),
        'which ends with a `/`.',
      }):concat(' '))
      return
    end
    filepath = filepath:add_suffix '.md'
  end
  return filepath, relative
end

---Call attempt to edit a file, catches and suppresses the error caused by a swap file being
---present. Re-raises other errors via log.error
---@param path string
M.edit_file = function(path)
  local ok, err = pcall(vim.cmd.edit, path)
  if not ok then
    if err and not err:match 'Vim:E325' then
      log.error(('Failed to edit file %s. Error:\n%s'):format(path, err))
    end
  end
end

---Resolve `$<workspace>/path/to/file` and return the real path
-- NOTE: Use `expand_pathlib` which returns a PathlibPath object instead.
---
---\@deprecate Use `expand_pathlib` which returns a PathlibPath object instead. TODO: deprecate this <2024-03-27>
---@param path string|PathlibPath # path
---@param raw_path boolean? # If true, returns resolved path, otherwise, returns resolved path and append ".down"
---@return string? # Resolved path. If path does not start with `$` or not absolute, adds relative from current file.
M.expand_path = function(path, raw_path)
  local res = M.expand_pathlib(path, raw_path)
  return res and res:tostring() or nil
end
M.get_workspaces = function()
  return M.config.workspaces
end
---@return string[]
M.get_wsnames = function()
  return vim.tbl_keys(M.config.workspaces)
end
--- If present retrieve a workspace's path by its name, else returns nil
---@param name string #The name of the workspace
M.get_workspace = function(name)
  return M.config.workspaces[name]
end
--- Returns a table in the format { "wsname", "path" }
M.get_current_workspace = function()
  return M.current_workspace
end
--- Sets the workspace to the one specified (if it exists) and broadcasts the wschanged event
---@param ws_name string #The name of a valid namespace we want to switch to
---@return boolean #True if the workspace is set correctly, false otherwise
M.set_workspace = function(ws_name)
  local workspace = M.config.workspaces[ws_name]
  local new_workspace = { ws_name, workspace }
  if not workspace then
    log.warn('Unable to set workspace to' .. workspace .. '- that workspace does not exist')
    return false
  end
  workspace:mkdir(Path.const.o755, true)
  local current_ws = vim.deepcopy(M.current_workspace)
  M.current_workspace = new_workspace
  if ws_name ~= 'default' then
    M.dep['data'].put('last_workspace', ws_name)
  end
  local e =
      mod.new_event(M, 'workspace.events.wschanged', { old = current_ws, new = new_workspace })
  mod.broadcast(e)

  return true
end
--- Dynamically defines a new workspace if the name isn't already occupied and broadcasts the wsadded event
---@return boolean True if the workspace is added successfully, false otherwise
---@param wsname string #The unique name of the new workspace
---@param wspath string|PathlibPath #A full path to the workspace root
M.add_workspace = function(wsname, wspath)
  if M.config.workspaces[wsname] then
    return false
  end
  wspath = Path(wspath):resolve():to_absolute()
  M.config.workspaces[wsname] = wspath
  mod.broadcast(mod.new_event(M, 'workspace.events.wsadded', { wsname, wspath }))
  M.sync()
  return true
end
--- If the file we opened is within a workspace directory, returns the name of the workspace, else returns nil
M.get_wsmatch = function()
  -- Cache the current working directory
  M.config.workspaces.default = Path.cwd()

  local file = Path(vim.fn.expand '%:p')

  -- Name of matching workspace. Falls back to "default"
  local ws_name = 'default'

  -- data the depth of the longest match
  local longest_match = 0

  -- Find a matching workspace
  for workspace, loc in pairs(M.config.workspaces) do
    if workspace ~= 'default' then
      if file:is_relative_to(loc) and loc:depth() > longest_match then
        ws_name = workspace
        longest_match = loc:depth()
      end
    end
  end

  return ws_name
end
--- Uses the `get_wsmatch()` function to determine the root of the workspace defaultd on the
--- current working directory, then changes into that workspace
M.set_closest_wsmatch = function()
  local ws_match = M.get_wsmatch()
  if ws_match then
    M.set_workspace(ws_match)
  else
    M.set_workspace 'default'
  end
end
--- Updates completions for the :down command
M.sync = function()
  -- Get all the workspace names
  local wsnames = M.get_wsnames()
  M.commands.workspace.complete = { wsnames }
  M.dep['data'].put('workspaces', wsnames)
  M.dep['data'].put('last_workspace', M.config.default)

  -- Add the command to default.cmd so it can be used by the user!
  mod.await('cmd', function(cmd)
    cmd.add_commands_from_table(M.commands)
  end)
end
--- @param prompt? string | nil
--- @param fmt? fun(item: string): string
--- @param fn? fun(item: number|string, idx: number|string)|nil
M.select = function(prompt, fmt, fn)
  local format = fmt
      or function(item)
        local current = M.get_current_workspace()
        if item == current then
          return '• ' .. item
        end
        return item
      end
  local func = fn
      or function(item, idx)
        local current = M.get_current_workspace()
        if not item then
          return
        elseif item == current then
          utils.notify('Already in workspace ' .. current)
        else
          utils.notify('Workspace set to ' .. item)
          M.set_workspace(item)
        end
        M.open_workspace(item)
      end
  return vim.ui.select(vim.tbl_keys(M.get_workspaces()), {
    prompt = prompt or 'Select workspace',
    format_items = format,
  }, func)
end
M.set_selected = function()
  local workspace = M.select()
  M.set_workspace(workspace)
  utils.notify('Changed workspace to ' .. workspace)
end

---@class down.mod.workspace.CreateFileOpts
---@field open? boolean do not open the file after creation?
---@field force? boolean overwrite file if it already exists?

--- Takes in a path (can include directories) and creates a .down file from that path
---@param path string|PathlibPath a path to place the .down file in
---@param workspace? string workspace name
---@param opts? down.mod.workspace.CreateFileOpts
M.new_file = function(path, workspace, opts)
  opts = opts or { open = true, force = false }
  local fullpath
  if workspace ~= nil then
    fullpath = M.get_workspace(workspace)
  else
    fullpath = M.get_current_workspace()[2]
  end
  if fullpath == nil then
    log.error 'Error in fetching workspace path'
    return
  end
  local destination = (fullpath / path):add_suffix '.md'
  destination:parent_assert():mkdir(Path.const.o755 + 4 * math.pow(8, 4), true) -- 40755(oct)
  local fd = destination:fs_open(opts.force and 'w' or 'a', Path.const.o644, false)
  if fd then
    vim.loop.fs_close(fd)
  end
  local bufnr = M.get_file_bufnr(destination:tostring())
  mod.broadcast(
    mod.new_event(M, 'workspace.events.file_created', { buffer = bufnr, opts = opts })
  )
  if opts.open then
    vim.cmd('e ' .. destination:tostring() .. '| silent! w')
  end
end

--- Takes in a workspace name and a path for a file and opens it
---@param wsname string #The name of the workspace to use
---@param path string|PathlibPath #A path to open the file (e.g directory/filename.down)
M.open_file = function(wsname, path)
  local workspace = M.get_workspace(wsname)
  if workspace == nil then
    return
  end
  vim.cmd('e ' .. (workspace / path):cmd_string() .. ' | silent! w')
end
M.set_last_workspace = function()
  local data = M.dep['data']
  if not data then
    log.trace "M `default.` not loaded, refusing to load last user's workspace."
    return
  end
  local last_workspace = M.dep['data'].get 'last_workspace'
  last_workspace = type(last_workspace) == 'string' and last_workspace or M.config.default or ''
  local wspath = M.get_workspace(last_workspace)
  if not wspath then
    log.trace(
      "Unable to switch to workspace '" .. last_workspace .. "'. The workspace does not exist."
    )
    return
  end
  if M.set_workspace(last_workspace) then
    vim.cmd('e ' .. (wspath / M.index()):cmd_string())
    utils.notify('Last workspace -> ' .. wspath)
  end
end
--- Checks for file existence by supplying a full path in `filepath`
---@param filepath string|PathlibPath
M.file_exists = function(filepath)
  return Path(filepath):exists()
end
--- Get the bufnr for a `filepath` (full path)
---@param filepath string|PathlibPath
M.get_file_bufnr = function(filepath)
  if M.file_exists(filepath) then
    local uri = vim.uri_from_fname(tostring(filepath))
    return vim.uri_to_bufnr(uri)
  end
end
--- Returns a list of all files relative path from a `wsname`
---@param wsname string
---@return PathlibPath[]|nil
M.get_note_files = function(wsname)
  local workspace = M.get_workspace(wsname)
  if not workspace then
    return
  end
  local nd = mod.get_mod 'note'.config.note_dir
  local wn = Path(workspace / nd)
  local res = {} ---@type table<PathlibPath>
  for p in wn:fs_iterdir(true, 20) do
    if p:is_file(true) and p:suffix() == '.md' then
      table.insert(res, p)
    end
  end
  return res
end
--- Returns a list of all files relative path from a `wsname`
---@param wsname string
---@return PathlibPath[]|nil
M.get_dirs = function(wsname)
  local res = {}
  local workspace = M.get_workspace(wsname)
  if not workspace then
    return
  end
  for p in workspace:fs_iterdir(true, 20) do
    if p:is_file(false) then
      table.insert(res, p)
    end
  end
  return res
end
--- Returns a list of all files relative path from a `wsname`
---@param wsname string
---@return PathlibPath[]|nil
M.get_files = function(wsname)
  local res = {}
  local workspace = M.get_workspace(wsname)
  if not workspace then
    return
  end
  for p in workspace:fs_iterdir(true, 20) do
    if p:is_file(true) then
      table.insert(res, p)
    end
  end
  return res
end
--- Returns a list of all files relative path from a `wsname`
---@param wsname string
---@return PathlibPath[]|nil
M.get_markdown_files = function(wsname)
  local res = {}
  local workspace = M.get_workspace(wsname)
  if not workspace then
    return
  end
  for p in workspace:fs_iterdir(true, 20) do
    if p:is_file(true) and p:suffix() == '.md' then
      table.insert(res, p)
    end
  end
  return res
end
--- Sets the current workspace and opens that workspace's index file
---@param workspace string #The name of the workspace to open
M.open_workspace = function(workspace)
  local ws_match = M.get_workspace(workspace)
  if not ws_match then
    log.error('Unable to switch to workspace - "' .. workspace .. '" does not exist')
    return
  end
  M.set_workspace(workspace)
  if workspace ~= 'default' then
    vim.cmd('e ' .. (ws_match / M.index()):cmd_string())
  end
end
--- Touches a file in workspace
---@param path string|PathlibPath
---@param workspace string
M.touch = function(p, workspace)
  vim.validate {
    path = { p, 'string', 'table' },
    workspace = { workspace, 'string' },
  }
  local ws_match = M.get_workspace(workspace)
  if not workspace then
    return false
  end
  return (ws_match / p):touch(Path.const.o644, true)
end
M.index = function()
  return M.indexfmt()
end
M.new_note = function()
  if M.config.use_popup then
    M.dep.ui.new_prompt('downNewNote', 'New Note: ', function(text)
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
    vim.ui.input({ prompt = 'New Note: ' }, function(text)
      if text ~= nil and #text > 0 then
        M.new_file(text)
      end
    end)
  end
end

M.get_dir = function(wsname)
  if not wsname then
    return M.current_workspace[2]
  else
    return M.get_workspace(wsname)
  end
end

M.subpath = function(p, wsname)
  local wsp = M.get_dir(wsname)
  return vim.fs.joinpath(wsp, p)
end

M.is_subpath = function(p, wsname)
  local wsp = M.get_dir(wsname)
  return not not p:match('^' .. wsp)
end

M.commands = {
  -- enabled = false,
  index = {
    -- enabled = false,
    args = 0,
    max_args = 1,
    name = 'workspace.index',
    complete = { M.get_wsnames() },
    callback = function(e)
      local current_ws = M.get_current_workspace()
      local index_path = current_ws[2] / M.indexfmt()
      if vim.fn.filereadable(index_path:tostring '/') == 0 then
        if not index_path:touch(Path.const.o644, true) then
          return
        end
      end
      M.edit_file(index_path:cmd_string())
    end
  },
  workspace = {
    max_args = 1,
    name = 'workspace.workspace',
    complete = { M.get_wsnames() },
    callback = function(event)
      if event.body[1] then
        M.open_workspace(event.body[1])
        vim.schedule(function()
          local new_workspace = M.get_workspace(event.body[1])
          if not new_workspace then
            M.select()
          end
          utils.notify('New workspace: ' .. event.body[1] .. ' -> ' .. new_workspace)
        end)
      else
        M.select()
      end
    end
  },
}

---@class down.mod.workspace.Events
M.events = {
  wschanged = Event.define(M, 'wschanged'),
  wsadded = Event.define(M, 'wsadded'),
  wscache_empty = Event.define(M, 'wscache_empty'),
  file_created = Event.define(M, 'file_created'),
}

---@class down.mod.workspace.Subscribed
M.handle = {
  workspace = {
    wsadded = function(e)
      log.trace(e, 'wsadded')
    end,
    file_created = function(e)
      log.trace('filecreated', e)
    end,
    wscache_empty = function(e)
      log.trace('wscache_empty', e)
    end,
    wschanged = function(e)
      log.trace('wschanged', e)
    end
  },
}

return M
