local Data = require ("down.mod.data")
local Global = require ("down.global")
local event = require ("down.event")
local log = require ("down.log")
local mod = require ("down.mod")
local utils = require ("down.util")

local fn, fs, it, uv, dbg =
  vim.fn, vim.fs, vim.iter, (vim.uv or vim.loop), vim.print

---@class down.Workspace: string
---@class down.Workspaces: { [string]?: string }

---@class down.mod.workspace.Workspace: down.Workspaceod
local Workspace = mod.new ("workspace")
Workspace.dep = { "ui", "data", "note", "cmd" }

---@return string
Workspace.path = function (name)
  return fs.normalize (fn.resolve (fn.expand (Workspace.data.workspaces[name])))
end

Workspace.home = function ()
  return Workspace.path (uv.os_homedir ())
end

---@class down.mod.workspace.Data
Workspace.data = Data.wrap ("workspace", {
  ---@type down.Workspaces
  workspaces = {},
  ---@type table<string, table>
  workspace_options = {},
  ---@type down.Workspace[]
  history = {},
  ---@type string?
  active = nil,
  ---@type string?
  default = nil,
  ---@type string?
  previous = nil,
})

---@class down.mod.workspace.Config
Workspace.config = {
  --- default workspace
  default = "default",
  --- List of workspaces
  workspaces = {
    default = vim.fn.getcwd (0),
    cwd = vim.fn.getcwd (0),
  },
  --- Per-workspace metadata, e.g. { path = "...", wiki = false }
  workspace_options = {},
  --- The filetype of new douments, markdown is supported only for now
  ft = "markdown",
  --- The default index to use
  index = "index",
  ext = ".md",
  -- if `false`, will use vim's default `vim.ui.input` instead.
  use_popup = true,
  --- Git sync configuration
  git = {
    enabled = true,
    auto_commit = true,
    auto_push = false,
    auto_pull = true,
    commit_message = "docs: update %file% (%date% %time%)",
    batch_commit_message = "docs: sync workspace %workspace% (%date%)",
    debounce_ms = 5000,
    branch = nil,
    remote = "origin",
    notify = true,
    sync_interval = 0,
    exclude = {},
    auto_init = false,
  },
}

--- Merged setup - returns setup table after performing initialization
---@return down.mod.Setup
Workspace.setup = function ()
  vim.iter (Workspace.config.workspaces):each (function (k, v)
    Workspace.config.workspaces[k] = fs.normalize (fn.resolve (fn.expand (v)))
  end)
  -- Append-merge the neovim-config workspaces into the global store
  -- (~/.config/down/down.json) so they are tracked alongside profiles.
  Global.merge_workspaces (Workspace.config.workspaces)
  -- Load the active profile's workspaces (includes everything ever
  -- registered globally) and merge with config-declared ones.
  local profile_ws = Global.profile_workspaces ()
  Workspace.data.workspaces =
    vim.tbl_extend ("keep", profile_ws, Workspace.config.workspaces)
  Workspace.data.history = Workspace.data.history or {}
  local data = Global.load ()
  local active_profile = data.profiles[data.active_profile] or {}
  Workspace.data.default = active_profile.default
    or Workspace.config.default
    or Workspace.data.default
    or "default"
  Workspace.data.previous = Workspace.data.previous or "default"
  Workspace.data.active = Workspace.data.active
    or Workspace.data.default
    or "default"
  vim.api.nvim_create_autocmd ("BufEnter", {
    pattern = "*",
    callback = function ()
      mod.await ("cmd", function (cmd)
        cmd.add_commands_from_table (Workspace.commands)
      end)
    end,
  })
  Workspace.sync ()

  -- Auto-init workspace in Neovim config dir if no workspaces exist
  if not next (Workspace.data.workspaces) then
    local config_dir = vim.fn.stdpath ("config")
    local ws_path = config_dir .. "/.down"
    local ws_name = "nvim"
    vim.fn.mkdir (ws_path .. "/data", "p")
    local idx_path = ws_path .. "/index.md"
    if vim.fn.filereadable (idx_path) == 0 then
      local f = io.open (idx_path, "w")
      if f then
        f:write ([[
# Neovim Config

Auto-initialized workspace for Neovim configuration.
]])
        f:close ()
      end
    end
    Workspace.data.workspaces[ws_name] = ws_path
    Workspace.data.default = ws_name
    Workspace.data.active = ws_name
    Global.add_workspace (ws_name, ws_path)
  end

  -- Initialize git sync for all workspaces
  if Workspace.config.git and Workspace.config.git.enabled then
    vim.schedule (function ()
      local Git = require ("down.mod.workspace.git")
      for _, ws_path in pairs (Workspace.data.workspaces) do
        if vim.fn.isdirectory (ws_path) == 1 then
          Git.setup_workspace (ws_path, Workspace.config.git)
        end
      end
    end)
  end
  return {
    loaded = true,
  }
end

Workspace.maps = {
  { "n", ",di", "<cmd>Down index<CR>", "Down index" },
  { "n", ",dw", "<cmd>Down workspace<CR>", "Down workspaces" },
  { "n", ",dg", "<cmd>Down git status<CR>", "Git status" },
  { "n", ",dG", "<cmd>Down git sync<CR>", "Git sync" },
}

--- Returns an iterator for the workspaces
--- @return Iter
Workspace.iter = function ()
  return vim.iter (pairs (Workspace.data.workspaces))
end

--- Returns the workspace folder as lsp
--- @return lsp.WorkspaceFolder
--- @param name? string
--- @param path? string
Workspace.as_lsp_workspace = function (name, path)
  return {
    name = name or Workspace.data.active,
    uri = vim.uri_from_fname (
      path or Workspace.path (name or Workspace.data.active)
    ),
  }
end

--- Returns the workspace folders as lsp
--- @return lsp.WorkspaceFolder[]
Workspace.as_lsp_workspaces = function ()
  return vim
    .iter (Workspace.data.workspaces)
    :map (Workspace.as_lsp_workspace)
    :totable ()
end

--- Returns the index file for a workspace
---@class down.mod.workspace.Data
Workspace.index = function (p)
  return vim.fs.joinpath (
    p or Workspace.current_path (),
    Workspace.config.index .. Workspace.config.ext
  )
end

--- Returns the current workspace name
--- @return string
Workspace.current = function ()
  return Workspace.data.active
end

--- Returns the current workspace path
--- @return string
Workspace.current_path = function ()
  return Workspace.path (Workspace.data.active)
end

--- Returns all files in a workspace
--- @return string[]
Workspace.files = function (ws, patt)
  return vim.fn.globpath (Workspace.get (ws), patt or "**/*", true, true)
end

--- Opens a file in the current workspace or at path
---@param path string
Workspace.edit = function (path)
  vim.cmd ("silent! e " .. path or Workspace.index ())
end

--- If present retrieve a workspace's path by its name, else returns nil
---@param name string #The name of the workspace
Workspace.get = function (name)
  if not name then
    return Workspace.data.workspaces[Workspace.data.active]
  end
  return Workspace.data.workspaces[name]
end

Workspace.set = function (name, path)
  Workspace.data.workspaces[name] = Workspace.path (path)
end
Workspace.has = function (n)
  return Workspace.data.workspaces[n] ~= nil
end
--- Sets the workspace to the one specified (if it exists) and broadcasts the wschanged event
---@param n string #The name of a valid namespace we want to switch to
---@param create? boolean
---@return boolean #True if the workspace is set correctly, false otherwise
Workspace.set_workspace = function (n, create)
  if not Workspace.has (n) then
    log.warn (
      "Unable to set workspace to" .. n .. "- that workspace does not exist"
    )
    return false
  end
  local p = Workspace.path (Workspace.data.workspaces[n])
  fn.mkdir (p, "p")
  Workspace.data.previous = Workspace.data.active
  Workspace.data.active = n
  -- local e = mod.new_event(Workspace, 'workspace.events.wschanged', { old = ws, new = workspace })
  -- mod.broadcast(e or {})

  return true
end
--- Dynamically defines a new workspace if the name isn't already occupied and broadcasts the wsadded event
---@return boolean True if the workspace is added successfully, false otherwise
---@param wsname string #The unique name of the new workspace
---@param wspath string #A full path to the workspace root
Workspace.add_workspace = function (wsname, wspath)
  if Workspace.data.workspaces[wsname] then
    return false
  end
  wspath = Workspace.path (wspath)
  Workspace.data.workspaces[wsname] = wspath
  Global.add_workspace (wsname, wspath)
  mod.broadcast (
    mod.new_event (Workspace, "workspace.events.wsadded", { wsname, wspath })
      or {}
  )
  Workspace.sync ()
  return true
end

--- Deletes a workspace
---@param wsname string
Workspace.delete_workspace = function (wsname)
  if not Workspace.data.workspaces[wsname] then
    return false
  end
  if wsname == "default" then
    log.warn ("Cannot delete default workspace")
    return false
  end
  Workspace.data.workspaces[wsname] = nil
  Global.remove_workspace (wsname)
  if Workspace.data.active == wsname then
    Workspace.data.active = "default"
  end
  Workspace.sync ()
  vim.notify ("[down.nvim] Deleted workspace: " .. wsname, vim.log.levels.INFO)
  return true
end

--- Renames a workspace
---@param old_name string
---@param new_name string
Workspace.rename_workspace = function (old_name, new_name)
  if not Workspace.data.workspaces[old_name] then
    return false
  end
  if Workspace.data.workspaces[new_name] then
    return false
  end
  if old_name == "default" then
    log.warn ("Cannot rename default workspace")
    return false
  end

  local path = Workspace.data.workspaces[old_name]
  Workspace.data.workspaces[old_name] = nil
  Workspace.data.workspaces[new_name] = path
  Global.rename_workspace (old_name, new_name)

  if Workspace.data.active == old_name then
    Workspace.data.active = new_name
  end
  Workspace.sync ()
  vim.notify (
    "[down.nvim] Renamed workspace: " .. old_name .. " -> " .. new_name,
    vim.log.levels.INFO
  )
  return true
end

--- Updates completions for the :down command
Workspace.sync = function ()
  Workspace.data.workspace_folders = Workspace.as_lsp_workspaces ()
  Workspace.data.workspaces = Workspace.config.workspaces or {}
  Workspace.data.active = Workspace.data.active or Workspace.data.default
  Workspace.data.history = Workspace.data.history or {}
  mod.await ("cmd", function (cmd)
    cmd.add_commands_from_table (Workspace.commands)
  end)
end
--- @param prompt? string | nil
--- @param fmt? fun(item: string): string
--- @param fn? fun(item: number|string, idx: number|string)|nil
Workspace.select = function (prompt, fmt, fn)
  local format = fmt
    or function (item)
      local current = Workspace.current ()
      if item == current then
        return "• " .. item
      end
      return item
    end
  local func = fn
    or function (item, idx)
      local current = Workspace.current ()
      if not item then
        return
      elseif item == current then
        vim.notify ("Already in workspace " .. current)
      else
        vim.notify ("Workspace set to " .. item)
        Workspace.set_workspace (item)
      end
      Workspace.open (item)
    end
  return vim.ui.select (Workspace.names (), {
    prompt = prompt or "Select workspace",
    format_items = format,
  }, func)
end
Workspace.gets = function ()
  return Workspace.data.workspaces
end
Workspace.set_selected = function ()
  local workspace = Workspace.select ()
  Workspace.set_workspace (workspace or Workspace.data.default or "default")
  vim.notify ("Changed workspace to " .. workspace)
end

---@class down.mod.workspace.CreateFileOpts
---@field open? boolean do not open the file after creation?
---@field force? boolean overwrite file if it already exists?

--- Takes in a path (can include directories) and creates a .down file from that path
---@param path string
---@param workspace? string workspace name
---@param opts? down.mod.workspace.CreateFileOpts
Workspace.new_file = function (path, workspace, opts)
  opts = opts or { open = true, force = false }
  local fullpath
  if workspace ~= nil then
    fullpath = Workspace.get (workspace)
  else
    fullpath = Workspace.get (Workspace.current ())
  end
  if fullpath == nil then
    return log.error ("Error in fetching workspace path")
  end
  local destination = fs.joinpath (fullpath, path)
  local parent = fs.dirname (destination)
  if not fn.isdirectory (parent) then
    fn.mkdir (parent, "p")
  end
  -- mod.broadcast(
  --   mod.new_event(
  --     Workspace,
  --     "workspace.events.file_created",
  --     { buffer = vim.api.nvim_get_current_buf(), opts = opts }
  --   ) or {}
  -- )
  if opts.open then
    vim.cmd ("e " .. destination .. "| silent! w")
  end
end

--- Takes in a workspace name and a path for a file and opens it
---@param wsname string #The name of the workspace to use
---@param path string #A path to open the file (e.g directory/filename.down)
Workspace.open_file = function (wsname, path)
  local workspace = Workspace.get (wsname)
  if workspace == nil then
    return
  end
  vim.cmd ("e " .. fs.joinpath (workspace, path) .. " | silent! w")
end
Workspace.set_last_workspace = function ()
  local prev = Workspace.data.previous or Workspace.data.default or ""
  local wspath = Workspace.get (Workspace.data.previous)
  if not wspath then
    log.trace (
      "Unable to switch to workspace '"
        .. prev
        .. "'. The workspace does not exist."
    )
    return
  end
  if Workspace.set_workspace (prev) then
    vim.cmd ("e " .. Workspace.index (wspath))
    vim.notify ("Last workspace -> " .. wspath)
  end
end
--- Checks for file existence by supplying a full path in `filepath`
---@param filepath string
Workspace.exists = function (filepath)
  return fn.filereadable (filepath)
end
--- Get the bufnr for a `filepath` (full path)
---@param filepath string
Workspace.bufnr = function (filepath)
  if Workspace.exists (filepath) then
    local uri = vim.uri_from_fname (tostring (filepath))
    return vim.uri_to_bufnr (uri)
  end
end
--- Returns a list of all files relative path from a `wsname`
---@param wsname string
---@return string?
Workspace.notes = function (wsname, year, month)
  local workspace = Workspace.get (wsname)
  if not workspace then
    return
  end
  local nd = mod.get_mod ("note").config.note_folder
  local wn = vim.fs.joinpath (workspace, nd)
  return vim.fn.globpath (wn, "**/*.md", true, true)
end

Workspace.names = function ()
  return vim.tbl_keys (Workspace.data.workspaces)
end

Workspace.workspaces = function ()
  return Workspace.data.workspaces
end

Workspace.paths = function ()
  return vim.tbl_values (Workspace.data.workspaces)
end
--- Returns a list of all files relative path from a `wsname`
---@param name string
---@return string[]?
Workspace.markdown = function (name)
  return fn.globpath (Workspace.get (name), "**/*.md", true, true)
end
--- Sets the current workspace and opens that workspace's index file
---@param workspace string #The name of the workspace to open
Workspace.open = function (workspace)
  local ws_match = Workspace.get (workspace)
  if not ws_match then
    log.error (
      'Unable to switch to workspace - "' .. workspace .. '" does not exist'
    )
    return
  end
  Workspace.set_workspace (workspace)
  if workspace ~= "default" then
    vim.cmd ("e " .. Workspace.index (ws_match))
  end
end
--- Touches a file in workspace
---@param p string
---@param workspace string
Workspace.touch = function (p, workspace)
  vim.validate ({
    path = { p, "string", "table" },
    workspace = { workspace, "string" },
  })
  local ws_match = Workspace.get (workspace)
  if not workspace then
    return false
  end
  return fn.writefile ({}, fs.joinpath (ws_match, p))
end
Workspace.new_note = function ()
  if
    Workspace.config.use_popup
    and Workspace.dep.ui
    and Workspace.dep.ui.new_prompt
  then
    Workspace.dep.ui.new_prompt ("downNewNote", "New Note: ", function (text)
      Workspace.new_file (text)
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
    vim.ui.input ({ prompt = "New Note: " }, function (text)
      if text ~= nil and #text > 0 then
        Workspace.new_file (text)
      end
    end)
  end
end

Workspace.subpath = function (p, wsname)
  local wsp = Workspace.get (wsname)
  return fs.joinpath (wsp, p)
end

Workspace.is_subpath = function (p, wsname)
  local wsp = Workspace.get (wsname)
  return not not p:match ("^" .. wsp)
end

--- Edit index of current directory
--- @param e down.Event
Workspace.edit_index = function (e)
  local c = e.body[1] or Workspace.current ()
  local ws = fs.normalize (fn.expand (Workspace.get (c)))
  fn.mkdir (ws, "p")
  local index = Workspace.index (ws)
  if fn.filereadable (index) == 0 then
    if not fn.writefile ({}, index) then
      return vim.notify ("Failed to create index file")
    end
  end
  Workspace.edit (index)
end

--- @param prompt? string | nil
--- @param fmt? fun(item: string): string
--- @param fn? fun(item: number|string, idx: number|string)|nil
Workspace.select_file = function (prompt, fmt, fn)
  local format = fmt
    or function (item)
      local current = vim.fn.expand ("%:p")
      if item == current then
        return "• " .. item
      end
      return item
    end
  local func = fn
    or function (item, idx)
      local current = vim.fn.expand ("%:p")
      if not item then
        return
      elseif item == current then
        vim.notify ("Already editing " .. current)
      else
        vim.notify ("Editing " .. item)
        Workspace.edit (item)
      end
      Workspace.edit (item)
    end
  return vim.ui.select (Workspace.markdown (Workspace.current ()) or {}, {
    prompt = prompt or "Select markdown file in workspace",
    format_items = format,
  }, func)
end

--- Select markdown file in current workspace
---@param e down.Event
Workspace.filemenu = function (e)
  if e.body and e.body[1] then
    Workspace.edit (e.body[1])
  else
    Workspace.select_file ()
  end
end

--- Select workspace
--- @param e down.Event
Workspace.menu = function (e)
  if e.body and e.body[1] then
    Workspace.open (e.body[1])
    vim.schedule (function ()
      local new_workspace = Workspace.get (e.body[1])
      if not new_workspace then
        Workspace.select ()
      end
      vim.notify ("Workspace: " .. e.body[1] .. " -> " .. new_workspace)
    end)
  else
    Workspace.select ()
  end
end

Workspace.fmt = function ()
  return vim
    .iter (Workspace.workspaces ())
    :map (function (k, v)
      return k .. " -> " .. v
    end)
    :totable ()
end

---@class down.mod.workspace.Commands: { [string]: down.Command }
Workspace.commands = {
  index = {
    enabled = true,
    min_args = 0,
    max_args = 1,
    name = "workspace.index",
    complete = { Workspace.names () },
    callback = function (e)
      Workspace.edit_index (e)
    end,
  },
  workspace = {
    min_args = 0,
    max_args = 1,
    enabled = true,
    name = "workspace.workspace",
    complete = { Workspace.names () },
    callback = function (e)
      Workspace.menu (e)
    end,
    commands = {
      add = {
        name = "workspace.workspace.add",
        enabled = true,
        args = 0,
        callback = function (e)
          vim.ui.input ({ prompt = "New workspace name: " }, function (wsname)
            if not wsname or wsname == "" then
              return
            end
            vim.ui.input (
              { prompt = "New workspace path: ", default = vim.fn.getcwd () },
              function (wspath)
                if not wspath or wspath == "" then
                  return
                end
                Workspace.add_workspace (wsname, wspath)
                vim.notify (
                  "[down.nvim] Added workspace " .. wsname .. " at " .. wspath,
                  vim.log.levels.INFO
                )
              end
            )
          end)
        end,
      },
      delete = {
        name = "workspace.workspace.delete",
        enabled = true,
        args = 0,
        callback = function (e)
          vim.ui.select (
            Workspace.names (),
            { prompt = "Delete workspace:" },
            function (choice)
              if choice then
                Workspace.delete_workspace (choice)
              end
            end
          )
        end,
      },
      rename = {
        name = "workspace.workspace.rename",
        enabled = true,
        args = 0,
        callback = function (e)
          vim.ui.select (
            Workspace.names (),
            { prompt = "Rename workspace:" },
            function (choice)
              if choice then
                vim.ui.input (
                  { prompt = "New name for " .. choice .. ": " },
                  function (new_name)
                    if new_name and new_name ~= "" then
                      Workspace.rename_workspace (choice, new_name)
                    end
                  end
                )
              end
            end
          )
        end,
      },
    },
  },
  edit = {
    min_args = 0,
    max_args = 1,
    enabled = true,
    name = "workspace.edit",
    callback = function (e)
      Workspace.filemenu (e)
    end,
    complete = {
      Workspace.markdown (Workspace.current ()),
    },
  },
  git = {
    min_args = 0,
    max_args = 1,
    enabled = true,
    name = "workspace.git",
    callback = function (e)
      local Git = require ("down.mod.workspace.git")
      local ws_path = Workspace.current_path ()
      Git.status (ws_path, function (status)
        vim.notify (
          "[down.nvim] " .. Git.format_status (status),
          vim.log.levels.INFO
        )
      end)
    end,
    commands = {
      sync = {
        name = "workspace.git.sync",
        args = 0,
        callback = function ()
          local Git = require ("down.mod.workspace.git")
          local ws_path = Workspace.current_path ()
          Git.sync (ws_path, Workspace.config.git)
        end,
      },
      commit = {
        name = "workspace.git.commit",
        args = 0,
        callback = function ()
          local Git = require ("down.mod.workspace.git")
          local ws_path = Workspace.current_path ()
          Git.commit (ws_path, Workspace.config.git)
        end,
      },
      push = {
        name = "workspace.git.push",
        args = 0,
        callback = function ()
          local Git = require ("down.mod.workspace.git")
          local ws_path = Workspace.current_path ()
          Git.push (ws_path, Workspace.config.git)
        end,
      },
      pull = {
        name = "workspace.git.pull",
        args = 0,
        callback = function ()
          local Git = require ("down.mod.workspace.git")
          local ws_path = Workspace.current_path ()
          Git.pull (ws_path, Workspace.config.git)
        end,
      },
      status = {
        name = "workspace.git.status",
        args = 0,
        callback = function ()
          local Git = require ("down.mod.workspace.git")
          local ws_path = Workspace.current_path ()
          Git.status (ws_path, function (status)
            vim.notify (
              "[down.nvim] " .. Git.format_status (status),
              vim.log.levels.INFO
            )
          end)
        end,
      },
      init = {
        name = "workspace.git.init",
        args = 0,
        callback = function ()
          local Git = require ("down.mod.workspace.git")
          local ws_path = Workspace.current_path ()
          Git.init_repo (ws_path, Workspace.config.git)
        end,
      },
    },
  },
}

---@class down.mod.workspace.Events
Workspace.events = {
  wschanged = event.define (Workspace, "wschanged"),
  wsadded = event.define (Workspace, "wsadded"),
  wscache_empty = event.define (Workspace, "wscache_empty"),
  file_created = event.define (Workspace, "file_created"),
}

---@class down.mod.workspace.Subscribed
Workspace.handle = {
  workspace = {
    wsadded = function (e)
      log.trace (e, "wsadded")
    end,
    file_created = function (e)
      log.trace ("filecreated", e)
    end,
    wscache_empty = function (e)
      log.trace ("wscache_empty", e)
    end,
    wschanged = function (e)
      log.trace ("wschanged", e)
    end,
  },
}

return Workspace
