local Path = require 'pathlib'
local Event = require 'down.event'
local log = require 'down.util.log'
local util = require 'down.mod.workspace.util'
local mod = require 'down.mod'
local utils = require 'down.util'
local path = require 'plenary.path'
local notify = util.notify

---@alias down.mod.Workspace down.Mod
---@class down.mod.workspace.Workspace: down.Mod
local M = mod.new 'workspace'

M.homedir = function()
  return vim.fs.normalize(vim.fn.resolve(vim.loop or vim.uv).os_homedir())
end

---@return string
M.path = function(name)
  if M.config.workspaces[name] then
    return vim.fs.normalize(vim.fn.resolve(M.config.workspaces[name] or M.homedir()))
  end
  M.init(name, vim.fn.getcwd(0))
end


  ---@class down.mod.workspace.Item
M.workspace = setmetatable({
  ---@type any
  key = "",
  ---@type any
  value = {},
  namespace = function(key)
    return "down.workspace." .. key
  end,
  get = function(key)
    local data, ws = M.dep.data.get(key), M.workspace[key]
    if not ws == data then
      M.workspace.sync(key)
    end
    return M.workspace[key]
  end,
  set = function(key, val)
    M.workspace[key] = val
    M.dep.data.set(key, val)
  end,
  join = function(...)
    local key = vim.fn.join({...}, '.')
    return M.workspace.namespace(key)
  end,
  sync = function(key)
    log.trace("Syncing " .. key)
    local val = M.dep.data.get()
    if M.workspace[key] ~= M.dep.data.get(key) then
      if not M.workspace[key] then
        M.workspace[key] = val
      elseif not M.dep.data.get(key) then
        M.dep.data.set(key, M.workspace[key])
      else
      end
    end
  end,
}, {

  __call = function(...)
     vim.iter({...}):each(function(k)
        M.workspace.sync(k)
     end)
  end,
  __index = function(self, k) return self.get(k) end,
  __newindex = function(self, k, v) return self.set(k, v) end,
  ---@param a down.mod.workspace.Item
  ---@param b down.mod.workspace.Item
  __eq = function(a, b) return
    a.key == b.key and b.value == a.value
  end,
})

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
  active = vim.fn.getcwd(0),
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

M.data = {
  previous = 'default',

  workspaces = {},

}

M.maps = {
  { 'n', ',di',  '<CMD>Down index<CR>',               'Down index' },
  { 'n', ',dw',  '<CMD>Down workspace<CR>',           'Down workspaces' },
  { 'n', ',dfw', '<CMD>Telescope down workspace<CR>', 'Telescope down workspaces' },
  { 'n', ',d.',  '<CMD>Down workspace cwd<CR>',       'Down workspace in cw' },
}

---@return Iter
M.iter = function()
  return vim.iter(pairs(M.config.workspaces))
end

M.load = function()
  M.iter():map(function(n, p)
    M.config.workspaces[n] = M.path(p)
  end)
  M.workspace.set('workspaces', M.config.workspaces)
  vim.api.nvim_create_autocmd('BufEnter', {
    pattern = '*',
    callback = function()
      mod.await('cmd', function(cmd)
        cmd.add_commands_from_table(M.commands)
      end)
    end,
  })
  M.sync()
  if M.workspace.previous and vim.fn.argc(-1) == 0 then
    if M.previous.previous == 'default' then
      if not M.config.default then
        log.warn 'Configuration error in `default.workspace`: the `open_last_workspace` option is set to "default", but no default workspace is provided in the `default_workspace` configuration variable. defaulting to opening the last known workspace.'
        M.set_last_workspace()
        return
      end
      M.open(M.config.default)
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
---@type { [1]: string, [2]: string }
M.active = { 'default', vim.fn.getcwd(0) }

M.history = {}

M.current = function(n)
  return M.active
end

---@return string[]
M.files = function(ws, patt)
  return vim.fn.globpath(M.get(ws), patt or '**/*', true, true)
end

---Call attempt to edit a file, catches and suppresses the error caused by a swap file being
---present. Re-raises other errors via log.error
---@param path string
M.edit = function(path)
  local ok, err = pcall(vim.cmd.edit, path)
  if not ok and err and not string.match(err, 'Vim:E325') then
    log.error(string.format('Failed to edit file %s. Error:\n%s', path, err))
  end
end
-- --- @class down.mod.workspace.Workspace.Opts: {
-- ---   default?: boolean,
-- ---   private?: boolean,
-- ---   namespace?: string.buffer,
-- --- }
--
-- ---@class down.mod.workspace.Workspace
-- ---  @field public id string The name of the workspace
-- ---  @field public path string The path to the workspace
-- ---  @field public opts? down.mod.workspace.Workspace.Opts opts
-- M.workspace = setmetatable({
--   name = 'default',
--   path = path or vim.fn.getcwd(0),
--   opts = {
--     namespace = 'down.mod.workspace.default:',
--     default = true,
--   },
--   ns = function(n, p) return 'down.workspace.'..n..':'..p end,
--   new = function(name, path, default) return {
--     name = name,
--     path = path or M.active[2],
--     opts = {
--       namespace = M.workspace.ns(name, path or M.active[2]),
--       default = default or false
--     }
--   } end
-- }, {
--     ---@param a down.mod.workspace.Workspace
--   __eq = function(a, b) return a.name ~= b.name end,
--     ---@param a down.mod.workspace.Workspace
--   __tostring = function(a) return a.opts.namespace end,
--     ---@param a down.mod.workspace.Workspace
--   __call = function(a) return a.path end,
--     ---@param a down.mod.workspace.Workspace
--     ---@param b down.mod.workspace.Workspace
--   __concat = function(a, b) return vim.fs.joinpath(a.path, b.path) end,
--     ---@param a down.mod.workspace.Workspace
--   __index = function(a, k) return a[k] end,
--     ---@param a down.mod.workspace.Workspace
--   __mode = function(a) return a.name end,
--     ---@param a down.mod.workspace.Workspace
--   __newindex = function(a, k, v)
--       a[k] = v
--   end,
--     ---@param a down.mod.workspace.Workspace
--    __len = function(a)
--       return table.len(vim.fn.globpath(a.path, '**/*.md', true, true))
--     end,
--   __metatable = 'down.workspace',
--
-- })
-- ---@class down.mod.workspace.Metatable: metatable
-- M.workspace.mt = {
-- }
--
M.list = function(filt)
  return vim.tbl_filter(filt or function(v)
    return true
  end, M.config.workspaces)
end

--- If present retrieve a workspace's path by its name, else returns nil
---@param name string #The name of the workspace
M.get = function(name)
  return M.config.workspaces[name]
end

M.set = function(name, path)
  M.config.workspaces[name] = util.path(path)
end
--- Returns a table in the format { "wsname", "path" }
M.get_active = function()
  return M.active
end
M.init = function(n, p)
  vim.iter(M.gets()):any(function(w)
    return w[1] ~= n and w[2] ~= n
  end)
end
--- Sets the workspace to the one specified (if it exists) and broadcasts the wschanged event
---@param ws_name string #The name of a valid namespace we want to switch to
---@param create? boolean
---@return boolean #True if the workspace is set correctly, false otherwise
M.set_workspace = function(ws_name, create)
  local wsexists, wspath = pcall(M.get, ws_name)
  if not wsexists then
    if create and create == true then
      M.init(wspath)
    end
  end
  local workspace = { ws_name, vim.fn.resolve(M.config.workspaces[ws_name]) }
  if not workspace[2] then
    log.warn('Unable to set workspace to' .. workspace .. '- that workspace does not exist')
    return false
  end
  vim.fn.mkdir(workspace[2], 'p')
  local ws = vim.deepcopy(M.active)
  M.active = workspace
  M.dep['data'].put('workspace.previous', ws_name)
  local e = mod.new_event(M, 'workspace.events.wschanged', { old = ws, new = workspace })
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
  wspath = M.path(wspath)
  M.config.workspaces[wsname] = wspath
  M.dep.data.set('workspace.workspaces', M.config.workspaces)
  mod.broadcast(mod.new_event(M, 'workspace.events.wsadded', { wsname, wspath }))
  M.sync()
  return true
end
--- If the file we opened is within a workspace directory, returns the name of the workspace, else returns nil
M.get_wsmatch = function()
  M.config.workspaces.default = util.path(vim.fn.getcwd())
  local file = util.path(vim.fn.expand '%:p')
  local ws_name = 'default'
  local longest_match, depth = 0, 0
  -- vim.iter(pairs(M.gets())):each(function(n, w)
  --   if n == 'default' and or > longest_match then
  --     ws_name = workspace
  --     longest_match = depth + 1
  --   end
  -- end)
  for wwn, loc in M.iter() do
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
M.closest = function()
  M.set_workspace(M.get_wsmatch() or 'default')
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
        local current = M.get_active()
        if item == current then
          return '• ' .. item
        end
        return item
      end
  local func = fn
      or function(item, idx)
        local current = M.get_active()
        if not item then
          return
        elseif item == current then
          utils.notify('Already in workspace ' .. current)
        else
          utils.notify('Workspace set to ' .. item)
          M.set_workspace(item)
        end
        M.open(item)
      end
  return vim.ui.select(vim.tbl_keys(M.gets()), {
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
    fullpath = M.get(workspace)
  else
    fullpath = M.get_active()[2]
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
  mod.broadcast(mod.new_event(M, 'workspace.events.file_created', { buffer = bufnr, opts = opts }))
  if opts.open then
    vim.cmd('e ' .. destination:tostring() .. '| silent! w')
  end
end

--- Takes in a workspace name and a path for a file and opens it
---@param wsname string #The name of the workspace to use
---@param path string|PathlibPath #A path to open the file (e.g directory/filename.down)
M.open_file = function(wsname, path)
  local workspace = M.get(wsname)
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
  local wspath = M.get(last_workspace)
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
  local workspace = M.get(wsname)
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
  local workspace = M.get(wsname)
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
---@return string[]
M.files = function(wsname)
  local res = {}
  local workspace = M.get(wsname)
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

M.names = function()
  return vim.tbl_keys(M.config.workspaces)
end

M.paths = function()
  return vim.tbl_values(M.config.workspaces)
end
--- Returns a list of all files relative path from a `wsname`
---@param name string
---@return string[]?
M.markdown = function(name)
  return vim.fn.globpath(M.path(name), '**/*.md', true, true)
end
--- Sets the current workspace and opens that workspace's index file
---@param workspace string #The name of the workspace to open
M.open = function(workspace)
  local ws_match = M.get(workspace)
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
---@param p string
---@param workspace string
M.touch = function(p, workspace)
  vim.validate {
    path = { p, 'string', 'table' },
    workspace = { workspace, 'string' },
  }
  local ws_match = M.get(workspace)
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
    return M.active[2]
  else
    return M.get(wsname)
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
      local current_ws = M.get_active()
      local index_path = current_ws[2] / M.indexfmt()
      if vim.fn.filereadable(index_path:tostring '/') == 0 then
        if not index_path:touch(Path.const.o644, true) then
          return
        end
      end
      M.edit(index_path:cmd_string())
    end,
  },
  workspace = {
    max_args = 1,
    name = 'workspace.workspace',
    complete = { M.get_wsnames() },
    callback = function(event)
      if event.body[1] then
        M.open(event.body[1])
        vim.schedule(function()
          local new_workspace = M.get(event.body[1])
          if not new_workspace then
            M.select()
          end
          utils.notify('New workspace: ' .. event.body[1] .. ' -> ' .. new_workspace)
        end)
      else
        M.select()
      end
    end,
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
    end,
  },
}

return M
