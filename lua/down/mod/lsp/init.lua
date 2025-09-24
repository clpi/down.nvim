local config = require("down.config")
local log = require("down.log")
local lsputil = require("down.mod.lsp.util")
local mod = require("down.mod")
local settings = require("down.mod.lsp.settings")
local ws = require("down.mod.workspace")
local lsp = vim.lsp
local lspu = vim.lsp.util
local cwd = vim.fn.getcwd
local ft = vim.bo.filetype
local key = vim.keymap.set
local acmd = vim.api.nvim_create_autocmd
local trc, inf, err, wrn = log.trace, log.info, log.error, log.warn

---@class down.mod.lsp.Lsp: down.Mod
local Lsp = mod.new "lsp"

--- @class down.mod.lsp.Maps: down.Map[]
Lsp.maps = {
  { 'n', '-dli', function() Lsp.util.install() end,                  "Install LSP" },
  { 'n', '-dlu', function() Lsp.util.install({ update = true }) end, "Update LSP" },
}

--- Utility LSP functions
Lsp.util = lsputil

--- LSP on attach
Lsp.on_attach = function()
  -- vim.print("attached down.lsp")
end

--- Load the lsp and clone the repo
Lsp.load = function()
  if vim.fn.exepath("down.lsp") == "" then
    lsputil.install({ update = true })
  end
  -- print("loading")
  Lsp.autocmd()
end
-- vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "BufNewFile" }, {
-- })

---@class down.mod.lsp.LspOpts: vim.lsp.start.Opts
Lsp.lsp_opts = {
  bufnr = 0,
  reuse_client = function(b)
    return true
  end,
  silent = true,
}

---@return down.mod.Setup
Lsp.setup = function()
  ---@type down.mod.Setup
  return {
    loaded = true,
    dependencies = {
      "cmd",
      "workspace",
    },
  }
end

--- @class down.mod.lsp.Commands: { [string]: down.Command }
Lsp.commands = {
  lsp = {
    name = "lsp",
    condition = "markdown",
    enabled = true,
    callback = function(e)
      trc("lsp", e)
    end,
    commands = {
      restart = {
        args = 0,
        name = "lsp.restart",
        condition = "markdown",
        callback = function(e)
          log.trace("lsp.restart", e)
        end,
      },
      install = {
        enabled = true,
        args = 0,
        name = "lsp.install",
        condition = "markdown",
        callback = function(e)
          log.trace("lsp.install", e)
          lsputil.install()
        end,
      },
      update = {
        enabled = true,
        args = 0,
        name = "lsp.update",
        condition = "markdown",
        callback = function(e)
          log.trace("lsp.update", e)
          lsputil.install({ update = true })
        end,
      },
      start = {
        args = 0,
        name = "lsp.start",
        condition = "markdown",
        callback = function(e)
          log.trace("lsp.start", e)
        end,
      },
      status = {
        args = 0,
        name = "lsp.status",
        condition = "markdown",
        callback = function(e)
          log.trace("lsp.status")
        end,
      },
      stop = {
        args = 0,
        name = "lsp.stop",
        enabled = true,
        condition = "markdown",
        callback = function(e)
          log.trace("lsp.stop")
        end,
      },
    },
  },
  actions = {
    args = 1,
    name = "actions",
    condition = "markdown",
    callback = function(e)
      log.trace("actions")
    end,
    commands = {
      workspace = {
        args = 1,
        name = "actions.workspace",
        condition = "markdown",
        callback = function(e)
          trc("actions.workspce", e)
        end,
      },
    },
  },
  rename = {
    args = 1,
    max_args = 1,
    name = "rename",
    condition = "markdown",
    commands = {
      workspace = {
        args = 0,
        max_args = 1,
        min_args = 0,
        name = "rename.workspace",
        complete = { require("down.mod.workspace").workspaces() },
        condition = "markdown",
        callback = function(e)
          trc("rename.workspace", e)
        end,
      },
      dir = {
        args = 0,
        name = "rename.dir",
        condition = "markdown",
        callback = function(e)
          trc(e, "rename.dir")
        end,
      },
      section = {
        args = 0,
        name = "rename.section",
        condition = "markdown",
        callback = function(e)
          trc(e, "rename.section")
        end,
      },
      file = {
        args = 0,
        max_args = 1,
        complete = { require("down.mod.workspace").files() },
        name = "rename.file",
        condition = "markdown",
        callback = function(e)
          log.trace("rename.file")
        end,
      },
    },
  },
}

---@class down.mod.lsp.Config: vim.lsp.ClientConfig
Lsp.info = {
  name = "downls",
  cmd = { "down.lsp", "lsp" },
  -- root_dir = ws.as_lsp_workspace(ws.current()),
  -- workspace_folders = ws.as_lsp_workspaces(),
  settings = settings,
}

function Lsp.run()
  if Lsp.is_md() then
    vim.lsp.start(Lsp.info)
  end
end

function Lsp.augroup()
  return vim.api.nvim_create_augroup("down.lsp", {
    clear = true,
  })
end

function Lsp.start()
  vim.lsp.start({
    name = "downls",
    on_error = function(ei, es)
      if config.dev or config.debug then
        vim.print("init", ei, es)
        vim.print(Lsp)
      end
    end,
    on_init = function(client, result)
      if config.dev and config.debug then
        vim.print("init", client, result)
      end
    end,
    on_exit = function(client, result)
      if config.dev and config.debug then
        vim.print("exit", client, result)
      end
    end,
    cmd = { "down.lsp", "lsp" },
    before_init = function(client, cfg)
      if config.dev and config.debug then
        vim.print("before_init", client, cfg)
      end
    end,
    root_dir = ws.current_path(),
    on_attach = Lsp.on_attach,
    workspace_folders = ws.as_lsp_workspaces(),
    settings = Lsp.config.settings,
  })
end

Lsp.autocmd = function(fty)
  return vim.api.nvim_create_autocmd({ "BufEnter" }, {
    -- group = Lsp.augroup(),
    pattern = fty or "*.md",
    once = false,
    group = Lsp.augroup(),
    callback = Lsp.start,
    nested = true,
    desc = "Run downls",
  })
end

Lsp.is_md = function()
  local ext = vim.fn.expand("%:e")
  return ext == "md" or ext == "markdown" or ext == "mdx"
end

Lsp.ft = function(fty)
  return vim.api.nvim_create_autocmd({ "FileType" }, {
    pattern = fty or "*",
    callback = Lsp.run,
    desc = "Run downls",
  })
end

-- ---@param e down.Event
-- Lsp.handle = {
--   cmd = {
--     ['rename'] = function(e) end,
--     ['action'] = function(e) end,
--     ['lsp'] = function(e) end,
--   },
-- }

return Lsp
